import sys, zlib, struct, glob, os, json
from pathlib import Path

FMT = {  # fourcc/d3d9 enum -> (label, bits per pixel, block bytes or None)
    0x31545844: ("DXT1", 4, 8), 0x33545844: ("DXT3", 8, 16), 0x35545844: ("DXT5", 8, 16),
    0x31495441: ("ATI1", 4, 8), 0x32495441: ("ATI2", 8, 16), 0x20374342: ("BC7", 8, 16),
    21: ("A8R8G8B8", 32, None), 32: ("A8B8G8R8", 32, None), 28: ("A8", 8, None), 50: ("L8", 8, None), 25: ("A1R5G5B5", 16, None),
}
def size_from_flags(flags):
    s = ((flags>>27)&1)<<0 | ((flags>>26)&1)<<1 | ((flags>>25)&1)<<2 | ((flags>>24)&1)<<3
    s += ((flags>>17)&0x7F)<<4; s += ((flags>>11)&0x3F)<<5; s += ((flags>>7)&0xF)<<6; s += ((flags>>5)&0x3)<<7; s += ((flags>>4)&1)<<8
    return (0x200 << (flags & 0xF)) * s
def tex_bytes(w,h,fmt,levels):
    lab,bpp,blk = FMT.get(fmt, ("?%08x"%fmt, 8, 16))
    total=0
    for i in range(max(1,levels)):
        mw,mh=max(1,w>>i),max(1,h>>i)
        total += ((mw+3)//4)*((mh+3)//4)*blk if blk else mw*mh*bpp//8
    return total
def inspect(path):
    raw=open(path,"rb").read()
    if raw[:4]!=b"RSC7": return {"file":path,"error":"not RSC7"}
    ver,sysf,gfxf=struct.unpack_from("<III",raw,4)
    virt,phys=size_from_flags(sysf),size_from_flags(gfxf)
    try: data=zlib.decompress(raw[16:],-15)
    except Exception as e:
        try: data=zlib.decompress(raw[16:])
        except Exception as e2: return {"file":path,"error":f"deflate: {e2}"}
    def u16(o): return struct.unpack_from("<H",data,o)[0]
    def u32(o): return struct.unpack_from("<I",data,o)[0]
    def u64(o): return struct.unpack_from("<Q",data,o)[0]
    def voff(p): return p & 0x0FFFFFFF
    texarr=u64(0x30); n=u16(0x38)
    texs=[]
    for i in range(n):
        tp=voff(u64(voff(texarr)+8*i))
        namep=voff(u64(tp+0x28)); name=data[namep:data.index(b"\0",namep)].decode("latin-1") if namep else ""
        w,h,d,stride=u16(tp+0x50),u16(tp+0x52),u16(tp+0x54),u16(tp+0x56); fmt=u32(tp+0x58); levels=data[tp+0x5D]
        texs.append({"name":name,"w":w,"h":h,"fmt":FMT.get(fmt,("?%08x"%fmt,))[0],"levels":levels,"bytes":tex_bytes(w,h,fmt,levels)})
    return {"file":path,"version":ver,"virt":virt,"phys":phys,"decompressed":len(data),"ntex":n,"sum_tex_bytes":sum(t["bytes"] for t in texs),"textures":texs}
if __name__=="__main__":
    out=[]
    for p in sys.argv[1:]:
        files=[str(x) for x in Path(p).rglob("*.ytd")] if os.path.isdir(p) else ([p] if os.path.exists(p) else glob.glob(p, recursive=True))
        for f in files: out.append(inspect(f))
    json.dump(out, open("ytd_report.json","w"), indent=1)
    for r in out:
        if "error" in r: print(f"ERR {r['file']}: {r['error']}"); continue
        big=[t for t in r["textures"] if max(t["w"],t["h"])>=2048]
        nomip=sum(1 for t in r["textures"] if t["levels"]<=1)
        print(f"{Path(r['file']).name:28s} phys={r['phys']/2**20:7.1f}MiB texsum={r['sum_tex_bytes']/2**20:7.1f}MiB ntex={r['ntex']:3d} >=2K={len(big):3d} nomip={nomip:3d} biggest={max(r['textures'],key=lambda t:t['bytes'])['name'] if r['textures'] else ''} {max((t['w'] for t in r['textures']),default=0)}px")
