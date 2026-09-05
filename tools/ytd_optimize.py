#!/usr/bin/env python3
"""
ytd_optimize.py - downscale / compress / add mipmaps to GTA V .ytd texture dictionaries (RSC7, PC).
No external tools: pure Python + numpy.

  python ytd_optimize.py "D:/.../[addon]"                 # dry run: report plan + savings per file
  python ytd_optimize.py "D:/.../[addon]" --apply         # rewrite in place, backup in --backup dir
  python ytd_optimize.py file.ytd --out ./test --max 1024 # write optimized copy to ./test

What it does per texture:
  * larger than --max (default 2048)      -> downscale (box filter). If the texture already has mipmaps
                                             and is block-compressed, the top mip levels are simply dropped (lossless).
  * uncompressed A8R8G8B8 / A8B8G8R8      -> re-encoded as DXT1 (opaque) or DXT5 (has alpha): 4-8x smaller
  * DXT3                                  -> DXT5
  * no mipmaps (1 level, >= --mip-min px) -> full mip chain generated (fixes shimmering + lets the GPU stream less)
Everything else (ATI1/ATI2/BC7/L8/A8, cubemaps, volumes) is copied untouched.
ponytail: simple range-fit DXT encoder; visually fine for car textures, slightly below texconv quality.
"""
import argparse, os, re, shutil, struct, sys, time, zlib
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import numpy as np

NORMAL_RE = re.compile(r"(_n|_nm|_nrm|_norm|_nor|_bump|normal)(\d+)?$", re.I)

DXT1, DXT3, DXT5 = 0x31545844, 0x33545844, 0x35545844
RGBA_FMTS = {21: "BGRA", 32: "RGBA"}          # D3DFMT_A8R8G8B8 (stored B,G,R,A), D3DFMT_A8B8G8R8 (stored R,G,B,A)
NAME = {DXT1: "DXT1", DXT3: "DXT3", DXT5: "DXT5", 21: "A8R8G8B8", 32: "A8B8G8R8", 0x31495441: "ATI1", 0x32495441: "ATI2", 0x20374342: "BC7", 28: "A8", 50: "L8"}
BLOCK_BYTES = {DXT1: 8, DXT3: 16, DXT5: 16, 0x31495441: 8, 0x32495441: 16, 0x20374342: 16}
PIX_BYTES = {21: 4, 32: 4, 28: 1, 50: 1, 25: 2}


# ---------------------------------------------------------------- RSC7 helpers
def size_from_flags(flags):
    s = ((flags >> 27) & 1) | (((flags >> 26) & 1) << 1) | (((flags >> 25) & 1) << 2) | (((flags >> 24) & 1) << 3)
    s += ((flags >> 17) & 0x7F) << 4
    s += ((flags >> 11) & 0x3F) << 5
    s += ((flags >> 7) & 0xF) << 6
    s += ((flags >> 5) & 0x3) << 7
    s += ((flags >> 4) & 1) << 8
    return (0x200 << (flags & 0xF)) * s


def flags_for_size(size):
    """Encode a physical/virtual segment size as RSC7 page flags (n pages of 16*base bytes)."""
    for ss in range(16):
        unit = (0x200 << ss) * 16
        n = -(-size // unit)
        if n <= 127:
            return (n << 17) | ss, n * unit
    raise ValueError("segment too large")


def level_bytes(w, h, fmt):
    if fmt in BLOCK_BYTES:
        return ((w + 3) // 4) * ((h + 3) // 4) * BLOCK_BYTES[fmt]
    return w * h * PIX_BYTES.get(fmt, 4)


def chain_bytes(w, h, fmt, levels):
    return sum(level_bytes(max(1, w >> i), max(1, h >> i), fmt) for i in range(levels))


BPP = {DXT1: 4, 0x31495441: 4, DXT3: 8, DXT5: 8, 0x32495441: 8, 0x20374342: 8, 21: 32, 32: 32, 28: 8, 50: 8, 25: 16}


def stride_for(w, fmt):
    # RAGE stores stride as width * bits-per-pixel / 8 even for block formats (DXT1 = w/2, DXT5 = w, RGBA = 4w);
    # verified on original files. A block-row pitch here makes the NVIDIA driver crash on upload.
    return max(1, w * BPP.get(fmt, 32) // 8)


# ---------------------------------------------------------------- DXT decode
def rgb565_to_rgb(c):
    c = c.astype(np.uint32)
    r, g, b = (c >> 11) & 31, (c >> 5) & 63, c & 31
    return np.stack([(r * 255 + 15) // 31, (g * 255 + 31) // 63, (b * 255 + 15) // 31], -1).astype(np.int32)


def decode_color_blocks(cb, dxt1):
    """cb: (N,8) uint8 color block -> (N,16,4) RGBA int32."""
    c0 = cb[:, 0].astype(np.uint16) | (cb[:, 1].astype(np.uint16) << 8)
    c1 = cb[:, 2].astype(np.uint16) | (cb[:, 3].astype(np.uint16) << 8)
    bits = cb[:, 4:8].astype(np.uint32)
    bits = bits[:, 0] | (bits[:, 1] << 8) | (bits[:, 2] << 16) | (bits[:, 3] << 24)
    idx = np.stack([(bits >> (2 * i)) & 3 for i in range(16)], 1)          # (N,16)
    p0, p1 = rgb565_to_rgb(c0), rgb565_to_rgb(c1)
    four = (c0 > c1) | (not dxt1)
    four3 = four[:, None]
    p2 = np.where(four3, (2 * p0 + p1) // 3, (p0 + p1) // 2)
    p3 = np.where(four3, (p0 + 2 * p1) // 3, 0)
    pal = np.stack([p0, p1, p2, p3], 1)                                      # (N,4,3)
    rgb = np.take_along_axis(pal, idx[:, :, None], 1)                        # (N,16,3)
    a = np.where(four[:, None] | (idx != 3), 255, 0)
    return np.concatenate([rgb, a[:, :, None]], -1)


def decode_dxt5_alpha(ab):
    a0, a1 = ab[:, 0].astype(np.int32), ab[:, 1].astype(np.int32)
    bits = np.zeros(len(ab), np.uint64)
    for i in range(6):
        bits |= ab[:, 2 + i].astype(np.uint64) << np.uint64(8 * i)
    idx = np.stack([((bits >> np.uint64(3 * i)) & np.uint64(7)).astype(np.int32) for i in range(16)], 1)
    eight = a0 > a1
    pal = np.zeros((len(ab), 8), np.int32)
    pal[:, 0], pal[:, 1] = a0, a1
    for k in range(1, 7):
        pal[:, k + 1] = np.where(eight, ((7 - k) * a0 + k * a1) // 7, 0)
    for k in range(1, 5):
        pal[:, k + 1] = np.where(eight, pal[:, k + 1], ((5 - k) * a0 + k * a1) // 5)
    pal[:, 6] = np.where(eight, pal[:, 6], 0)
    pal[:, 7] = np.where(eight, pal[:, 7], 255)
    return np.take_along_axis(pal, idx, 1)


def decode_dxt3_alpha(ab):
    bits = np.zeros(len(ab), np.uint64)
    for i in range(8):
        bits |= ab[:, i].astype(np.uint64) << np.uint64(8 * i)
    return np.stack([(((bits >> np.uint64(4 * i)) & np.uint64(15)).astype(np.int32)) * 17 for i in range(16)], 1)


def blocks_to_image(px, bw, bh, w, h):
    """px: (N,16,4) -> (h,w,4) uint8"""
    img = px.reshape(bh, bw, 4, 4, 4).transpose(0, 2, 1, 3, 4).reshape(bh * 4, bw * 4, 4)
    return img[:h, :w].astype(np.uint8)


def decode(data, w, h, fmt):
    """level-0 bytes -> (h,w,4) RGBA uint8"""
    if fmt in RGBA_FMTS:
        img = np.frombuffer(data, np.uint8)[: w * h * 4].reshape(h, w, 4).copy()
        if RGBA_FMTS[fmt] == "BGRA":
            img = img[:, :, [2, 1, 0, 3]]
        return img
    bw, bh = (w + 3) // 4, (h + 3) // 4
    blocks = np.frombuffer(data, np.uint8)[: bw * bh * BLOCK_BYTES[fmt]].reshape(bw * bh, BLOCK_BYTES[fmt])
    if fmt == DXT1:
        px = decode_color_blocks(blocks, True)
    else:
        px = decode_color_blocks(blocks[:, 8:], False)
        px[:, :, 3] = decode_dxt5_alpha(blocks[:, :8]) if fmt == DXT5 else decode_dxt3_alpha(blocks[:, :8])
    return blocks_to_image(px, bw, bh, w, h)


# ---------------------------------------------------------------- DXT encode (range fit)
def to565(rgb):
    rgb = rgb.astype(np.int32)
    return ((rgb[..., 0] * 31 + 127) // 255 << 11) | ((rgb[..., 1] * 63 + 127) // 255 << 5) | ((rgb[..., 2] * 31 + 127) // 255)


def encode(img, fmt):
    """img (h,w,4) uint8 -> bytes in DXT1 or DXT5"""
    h, w = img.shape[:2]
    ph, pw = -(-h // 4) * 4, -(-w // 4) * 4
    if (ph, pw) != (h, w):
        img = np.pad(img, ((0, ph - h), (0, pw - w), (0, 0)), mode="edge")
    bh, bw = ph // 4, pw // 4
    blocks = img.reshape(bh, 4, bw, 4, 4).transpose(0, 2, 1, 3, 4).reshape(bh * bw, 16, 4)
    n = len(blocks)
    rgb = blocks[:, :, :3].astype(np.float32)
    mn, mx = rgb.min(1), rgb.max(1)
    axis = mx - mn
    proj = ((rgb - mn[:, None]) * axis[:, None]).sum(-1)
    ar = np.arange(n)
    e_hi, e_lo = rgb[ar, proj.argmax(1)], rgb[ar, proj.argmin(1)]
    q0, q1 = to565(e_hi), to565(e_lo)
    swap = q0 < q1
    q0, q1 = np.where(swap, q1, q0), np.where(swap, q0, q1)
    p0, p1 = rgb565_to_rgb(q0), rgb565_to_rgb(q1)
    pal = np.stack([p0, p1, (2 * p0 + p1) // 3, (p0 + 2 * p1) // 3], 1).astype(np.float32)   # (N,4,3)
    d = ((rgb[:, :, None, :] - pal[:, None, :, :]) ** 2).sum(-1)                              # (N,16,4)
    idx = d.argmin(-1).astype(np.uint32)
    idx[q0 == q1] = 0
    cbits = np.zeros(n, np.uint32)
    for i in range(16):
        cbits |= idx[:, i] << np.uint32(2 * i)
    color = np.zeros((n, 8), np.uint8)
    color[:, 0], color[:, 1] = q0 & 255, q0 >> 8
    color[:, 2], color[:, 3] = q1 & 255, q1 >> 8
    for i in range(4):
        color[:, 4 + i] = (cbits >> np.uint32(8 * i)) & 255
    if fmt == DXT1:
        return color.tobytes()
    a = blocks[:, :, 3].astype(np.int32)
    a0, a1 = a.max(1), a.min(1)
    pal = np.stack([a0, a1] + [((7 - k) * a0 + k * a1) // 7 for k in range(1, 7)], 1)          # (N,8)
    aidx = np.abs(a[:, :, None] - pal[:, None, :]).argmin(-1).astype(np.uint64)
    aidx[a0 == a1] = 0
    abits = np.zeros(n, np.uint64)
    for i in range(16):
        abits |= aidx[:, i] << np.uint64(3 * i)
    alpha = np.zeros((n, 8), np.uint8)
    alpha[:, 0], alpha[:, 1] = a0, a1
    for i in range(6):
        alpha[:, 2 + i] = ((abits >> np.uint64(8 * i)) & np.uint64(255)).astype(np.uint8)
    return np.concatenate([alpha, color], 1).tobytes()


def halve(img):
    h, w = img.shape[:2]
    img = img[: h - h % 2, : w - w % 2]
    return img.reshape(h // 2, 2, w // 2, 2, 4).mean((1, 3)).round().astype(np.uint8)


# ---------------------------------------------------------------- YTD read / plan / write
class Tex:
    __slots__ = ("off", "name", "w", "h", "depth", "stride", "fmt", "levels", "dataoff", "nbytes", "plan", "new")


def read_ytd(path):
    raw = open(path, "rb").read()
    if raw[:4] != b"RSC7":
        raise ValueError("not RSC7")
    ver, sysf, gfxf = struct.unpack_from("<III", raw, 4)
    virt, phys = size_from_flags(sysf), size_from_flags(gfxf)
    data = bytearray(zlib.decompress(raw[16:], -15))
    u16 = lambda o: struct.unpack_from("<H", data, o)[0]
    u32 = lambda o: struct.unpack_from("<I", data, o)[0]
    u64 = lambda o: struct.unpack_from("<Q", data, o)[0]
    arr, n = u64(0x30) & 0x0FFFFFFF, u16(0x38)
    texs = []
    for i in range(n):
        t = Tex()
        t.off = u64(arr + 8 * i) & 0x0FFFFFFF
        namep = u64(t.off + 0x28) & 0x0FFFFFFF
        t.name = data[namep:data.index(b"\0", namep)].decode("latin-1") if namep else ""
        t.w, t.h, t.depth, t.stride = u16(t.off + 0x50), u16(t.off + 0x52), u16(t.off + 0x54), u16(t.off + 0x56)
        t.fmt, t.levels = u32(t.off + 0x58), data[t.off + 0x5D]
        t.dataoff = u64(t.off + 0x70) & 0x0FFFFFFF          # offset inside physical segment
        t.nbytes = chain_bytes(t.w, t.h, t.fmt, t.levels)
        t.plan = None
        t.new = None
        texs.append(t)
    return dict(ver=ver, sysf=sysf, gfxf=gfxf, virt=virt, phys=phys, data=data, texs=texs, raw=raw)


def plan(y, maxdim, mipmin, want_mips):
    for t in y["texs"]:
        t.plan = None
        if t.depth > 1 or t.fmt not in (DXT1, DXT3, DXT5, 21, 32):
            continue
        big = max(t.w, t.h)
        down = 0
        while big > maxdim and big > 4:
            big //= 2
            down += 1
        tw, th = max(1, t.w >> down), max(1, t.h >> down)
        want_fmt = t.fmt
        if t.fmt in RGBA_FMTS or t.fmt == DXT3:
            want_fmt = DXT5                       # refined to DXT1 at encode time if fully opaque
        need_mips = want_mips and t.levels <= 1 and max(tw, th) >= mipmin
        if not down and want_fmt == t.fmt and not need_mips:
            continue
        # lossless mip drop possible?
        if down and want_fmt == t.fmt and t.levels > down and not need_mips:
            t.plan = ("mipdrop", tw, th, want_fmt, t.levels - down)
        else:
            lv = 1
            if want_mips or t.levels > 1:
                while min(tw >> lv, th >> lv) >= 4 and lv < 16:
                    lv += 1
            t.plan = ("recode", tw, th, want_fmt, lv)
    return y


def planned_bytes(t):
    if not t.plan:
        return t.nbytes
    _, w, h, fmt, lv = t.plan
    return chain_bytes(w, h, fmt, lv)


def build(y, verbose=False):
    data = y["data"]
    physbase = y["virt"]
    for t in y["texs"]:
        if not t.plan:
            t.new = (bytes(data[physbase + t.dataoff: physbase + t.dataoff + t.nbytes]), t.w, t.h, t.fmt, t.levels)
            continue
        kind, w, h, fmt, lv = t.plan
        src = physbase + t.dataoff
        if kind == "mipdrop":
            skip = sum(level_bytes(max(1, t.w >> i), max(1, t.h >> i), t.fmt) for i in range(t.levels - lv))
            t.new = (bytes(data[src + skip: src + t.nbytes]), w, h, fmt, lv)
            continue
        img = decode(bytes(data[src: src + level_bytes(t.w, t.h, t.fmt)]), t.w, t.h, t.fmt)
        while img.shape[1] > w or img.shape[0] > h:
            img = halve(img)
        if fmt == DXT5 and t.fmt != DXT5 and img[:, :, 3].min() == 255 and not NORMAL_RE.search(t.name):
            fmt = DXT1                        # opaque colour/spec maps -> DXT1; normal maps stay DXT5 (precision)
        chunks = []
        cur = img
        for i in range(lv):
            chunks.append(encode(cur, fmt))
            if i + 1 < lv:
                cur = halve(cur)
        t.new = (b"".join(chunks), w, h, fmt, lv)
        if verbose:
            print(f"      {t.name:36s} {t.w}x{t.h} {NAME.get(t.fmt)} L{t.levels} -> {w}x{h} {NAME.get(fmt)} L{lv}  {t.nbytes/2**20:6.1f} -> {len(t.new[0])/2**20:6.1f} MiB")
    # physical segment: pages are separate allocations in the game, so no texture may cross a page boundary.
    # Page size = smallest 16*base (base = 0x200 << ss) that holds the largest texture; a blob that would
    # cross a boundary is pushed to the next page (the rule CodeWalker's ResourceBuilder applies).
    largest = max(len(t.new[0]) for t in y["texs"]) if y["texs"] else 1
    ss = 0
    while (0x200 << ss) * 16 < largest:
        ss += 1
    page = (0x200 << ss) * 16
    phys = bytearray()
    for t in y["texs"]:
        blob, w, h, fmt, lv = t.new
        pad = (-len(phys)) % 0x1000          # originals align every texture to 4 KiB
        if (len(phys) + pad) // page != (len(phys) + pad + len(blob) - 1) // page:
            pad = (-len(phys)) % page
        phys += b"\0" * pad
        off = len(phys)
        phys += blob
        struct.pack_into("<HHHH", data, t.off + 0x50, w, h, t.depth, stride_for(w, fmt))
        struct.pack_into("<I", data, t.off + 0x58, fmt)
        data[t.off + 0x5D] = lv
        struct.pack_into("<Q", data, t.off + 0x70, 0x60000000 | off)
        # 0x40: size of the texture data in 4 KiB pages (bits 12+), flags in the other bits. Stale value = client crash.
        old40 = struct.unpack_from("<I", data, t.off + 0x40)[0]
        pages = max(1, -(-len(blob) // 4096))
        struct.pack_into("<I", data, t.off + 0x40, (old40 & 0xE0000FFF) | (pages << 12))
    npages = -(-len(phys) // page)
    if npages > 127:
        raise ValueError("more than 127 physical pages; texture set too large for this layout")
    gfxf, physsize = (npages << 17) | ss, npages * page
    gfxf |= y["gfxf"] & 0xF0000000          # top nibble = resource version (13 for ytd); must be preserved
    phys += b"\0" * (physsize - len(phys))
    virt = bytes(data[: y["virt"]])
    co = zlib.compressobj(9, zlib.DEFLATED, -15)
    body = co.compress(virt + bytes(phys)) + co.flush()
    return struct.pack("<4sIII", b"RSC7", y["ver"], y["sysf"], gfxf) + body, physsize


def process_file(f, a):
    """Plan (and optionally rebuild) one ytd. Returns (log, before_bytes, after_bytes)."""
    log = []
    try:
        y = read_ytd(f)
    except Exception as e:
        return (f"SKIP {f}: {e}", 0, 0)
    if y["phys"] < a.min_mib * 2**20:
        return ("", 0, 0)
    plan(y, a.max, a.mip_min, not a.no_mips)
    before = y["phys"]
    est = sum(planned_bytes(t) for t in y["texs"]) + 0x100 * len(y["texs"])
    n_plan = sum(1 for t in y["texs"] if t.plan)
    log.append(f"{f.name:30s} {before/2**20:7.1f} MiB -> ~{est/2**20:7.1f} MiB  ({n_plan}/{len(y['texs'])} textures: "
               f"{sum(1 for t in y['texs'] if t.plan and t.plan[0]=='mipdrop')} mipdrop, {sum(1 for t in y['texs'] if t.plan and t.plan[0]=='recode')} recode)")
    if not (a.apply or a.out) or not n_plan:
        return ("\n".join(log), before, est if n_plan else before)
    t0 = time.time()
    out, physsize = build(y, a.v)
    try:
        chk = read_ytd_bytes(out, f.stem)
        assert len(chk["texs"]) == len(y["texs"]), "texture count changed"
        for t, c in zip(y["texs"], chk["texs"]):
            assert (c.w, c.h, c.fmt, c.levels) == (t.new[1], t.new[2], t.new[3], t.new[4]), f"header mismatch on {t.name}"
            assert c.dataoff + c.nbytes <= chk["phys"], f"data overflow on {t.name}"
    except Exception as e:
        log.append(f"   !! verification failed for {f.name}: {e} - file NOT written")
        return ("\n".join(log), before, before)
    if a.out:
        dst = Path(a.out) / f.name
        dst.parent.mkdir(parents=True, exist_ok=True)
    else:
        rel = f.resolve().as_posix().split("/txData/resources/", 1)[-1]
        bk = Path(a.backup) / rel
        bk.parent.mkdir(parents=True, exist_ok=True)
        if not bk.exists():
            shutil.copy2(f, bk)
        dst = f
    dst.write_bytes(out)
    log.append(f"   written {dst} ({len(out)/2**20:.1f} MiB on disk, {physsize/2**20:.1f} MiB in VRAM, {time.time()-t0:.0f}s)")
    return ("\n".join(log), before, physsize)


def _worker(args):
    return process_file(*args)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+", help=".ytd files or directories (recursive)")
    ap.add_argument("--max", type=int, default=2048, help="max texture dimension (default 2048)")
    ap.add_argument("--mip-min", type=int, default=256, help="generate mipmaps only for textures >= this size (default 256)")
    ap.add_argument("--no-mips", action="store_true", help="do not generate missing mipmaps")
    ap.add_argument("--apply", action="store_true", help="rewrite files in place (default: dry run)")
    ap.add_argument("--out", help="write optimized copies into this directory instead of in place")
    ap.add_argument("--backup", default="D:/game/FiveM/local4Word6/backups/ytd-" + time.strftime("%Y%m%d-%H%M%S"), help="backup dir for --apply")
    ap.add_argument("--min-mib", type=float, default=16.0, help="skip files whose physical size is below this (default 16 MiB)")
    ap.add_argument("--limit", type=int, default=0, help="process at most N files (testing)")
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) // 2), help="parallel processes (default: half the CPUs)")
    ap.add_argument("-v", action="store_true", help="per-texture log")
    a = ap.parse_args()
    files = []
    for p in a.paths:
        P = Path(p)
        files += [P] if P.is_file() else sorted(P.rglob("*.ytd"))
    if a.limit:
        files = files[: a.limit]
    tot_before = tot_after = 0
    t0 = time.time()
    jobs = [(f, a) for f in files]
    if a.workers > 1 and (a.apply or a.out) and len(jobs) > 1:
        with ProcessPoolExecutor(max_workers=a.workers) as ex:
            results = ex.map(_worker, jobs)
            for log, b, aft in results:
                if log:
                    print(log, flush=True)
                tot_before += b
                tot_after += aft
    else:
        for job in jobs:
            log, b, aft = _worker(job)
            if log:
                print(log, flush=True)
            tot_before += b
            tot_after += aft
    print(f"\nTOTAL {tot_before/2**30:.2f} GiB -> {tot_after/2**30:.2f} GiB  ({(1-tot_after/max(1,tot_before))*100:.0f}% less)  in {time.time()-t0:.0f}s"
          + ("" if (a.apply or a.out) else "   [dry run - add --apply or --out]"))


def read_ytd_bytes(b, tag="x"):
    tmp = Path(os.environ.get("TEMP", ".")) / f"_ytd_verify_{tag}_{os.getpid()}.ytd"
    tmp.write_bytes(b)
    try:
        return read_ytd(tmp)
    finally:
        tmp.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
