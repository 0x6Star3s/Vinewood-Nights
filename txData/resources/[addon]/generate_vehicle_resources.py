from pathlib import Path
import json
import re
import shutil
import sys
import xml.etree.ElementTree as ET

ADDON_DIR = Path(__file__).resolve().parent
VEHICLES_CFG = ADDON_DIR / "vehicles.cfg"
VMENU_ADDONS_JSON = ADDON_DIR.parent / "vMenu" / "config" / "addons.json"
QB_CORE_VEHICLES_LUA = ADDON_DIR.parent / "[core-important]" / "qb-core" / "shared" / "vehicles.lua"

GENERATED_QB_CORE_BEGIN = "    -- BEGIN AUTO-GENERATED ADDON VEHICLES"
GENERATED_QB_CORE_END = "    -- END AUTO-GENERATED ADDON VEHICLES"

VEHICLE_CLASS_TO_CATEGORY = {
    "VC_COMPACT": "Compacts",
    "VC_SEDAN": "Sedans",
    "VC_SUV": "SUVs",
    "VC_COUPE": "Coupes",
    "VC_MUSCLE": "Muscle",
    "VC_SPORT_CLASSIC": "Sports Classics",
    "VC_SPORT": "Sports",
    "VC_SUPER": "Super",
    "VC_MOTORCYCLE": "Motorcycles",
    "VC_OFF_ROAD": "Off Road",
    "VC_INDUSTRIAL": "Industrial",
    "VC_UTILITY": "Utility",
    "VC_VAN": "Vans",
    "VC_CYCLE": "Cycles",
    "VC_BOAT": "Boats",
    "VC_HELI": "Helicopters",
    "VC_PLANE": "Planes",
    "VC_SERVICE": "Service",
    "VC_EMERGENCY": "Emergency",
    "VC_MILITARY": "Military",
    "VC_COMMERCIAL": "Commercial",
    "VC_RAIL": "Trains",
    "VC_OPEN_WHEEL": "Open Wheel",
}

CATEGORY_DEFAULT_PRICE = {
    "Compacts": 15000,
    "Sedans": 90000,
    "SUVs": 160000,
    "Coupes": 120000,
    "Muscle": 110000,
    "Sports Classics": 180000,
    "Sports": 250000,
    "Super": 500000,
    "Motorcycles": 35000,
    "Off Road": 90000,
    "Industrial": 100000,
    "Utility": 75000,
    "Vans": 60000,
    "Cycles": 1000,
    "Boats": 150000,
    "Helicopters": 750000,
    "Planes": 1000000,
    "Service": 100000,
    "Emergency": 100000,
    "Military": 1000000,
    "Commercial": 120000,
    "Trains": 1000000,
    "Open Wheel": 1000000,
}

NON_PDM_CATEGORIES = {"Boats", "Helicopters", "Planes", "Cycles", "Emergency", "Military", "Trains"}

META_TYPES = {
    "handling.meta": "HANDLING_FILE",
    "vehicles.meta": "VEHICLE_METADATA_FILE",
    "carcols.meta": "CARCOLS_FILE",
    "carvariations.meta": "VEHICLE_VARIATION_FILE",
    "vehiclelayouts.meta": "VEHICLE_LAYOUTS_FILE",
    "dlctext.meta": "DLC_TEXT_FILE",
    "contentunlocks.meta": "CONTENT_UNLOCKING_META_FILE",
}

GENERATED_MANIFEST_HEADER = "resource_manifest_version '77731fab-63ca-442c-a67b-abc70f28dfa5'"

SKIP_FOLDERS = {"Pojazdyv2", "_old_Pojazdyv2_delete_me", "[generated]"}


WARNINGS: list[str] = []
RESOURCE_MODELS: dict[str, list[str]] = {}


def warn(message: str) -> None:
    WARNINGS.append(message)


def normalize_brand_name(name: str) -> str:
    return name.strip("[]").strip().lower()


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8", newline="\n")


def lua_quote(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "\\'")


def read_text_lossy(path: Path) -> str:
    for encoding in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
    return path.read_text(errors="replace")


def text_or_empty(element: ET.Element, tag_name: str) -> str:
    child = element.find(tag_name)
    return child.text.strip() if child is not None and child.text else ""


def friendly_name(raw_name: str, fallback: str) -> str:
    name = raw_name.strip() or fallback
    name = name.replace("_", " ").replace("-", " ")
    return " ".join(name.split())


def clean_xml(text: str) -> str:
    """RAGE toleruje komentarze typu <!------> i NUL-e na koncu pliku, expat nie."""
    text = text.replace(chr(0), "")
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    return text.strip()


def parse_xml(meta_path: Path):
    try:
        return ET.fromstring(clean_xml(read_text_lossy(meta_path)))
    except ET.ParseError as exc:
        warn(f"Nie da sie sparsowac {meta_path}: {exc}")
        return None


def parse_vehicle_meta(meta_path: Path, brand_fallback: str) -> list[dict[str, str | int]]:
    root = parse_xml(meta_path)
    if root is None:
        return []

    vehicles: list[dict[str, str | int]] = []
    for item in root.findall(".//InitDatas/Item"):
        model = text_or_empty(item, "modelName")
        if not model:
            continue

        category = VEHICLE_CLASS_TO_CATEGORY.get(text_or_empty(item, "vehicleClass"), "Sports")
        shop = "none" if category in NON_PDM_CATEGORIES else "pdm"
        vehicles.append({
            "model": model,
            "name": friendly_name(text_or_empty(item, "gameName"), model),
            "brand": friendly_name(text_or_empty(item, "vehicleMakeName"), brand_fallback.title()),
            "price": CATEGORY_DEFAULT_PRICE.get(category, 100000),
            "categoryLabel": category,
            "shop": shop,
        })

    return vehicles


def merge_or_rename_brand_folder(folder: Path) -> Path:
    brand_name = normalize_brand_name(folder.name)
    target = ADDON_DIR / f"[{brand_name}]"

    if folder == target:
        return target

    if target.exists():
        for child in folder.iterdir():
            destination = target / child.name
            if destination.exists():
                raise RuntimeError(f"Cannot merge duplicate path: {destination}")
            shutil.move(str(child), str(destination))
        folder.rmdir()
    else:
        folder.rename(target)

    return target


def model_has_manifest(model_dir: Path) -> bool:
    return (model_dir / "fxmanifest.lua").exists() or (model_dir / "__resource.lua").exists()


def model_looks_like_vehicle(model_dir: Path) -> bool:
    return (
        model_has_manifest(model_dir)
        or (model_dir / "data").exists()
        or (model_dir / "stream").exists()
    )


def data_file_names(model_dir: Path) -> list[str]:
    data_dir = model_dir / "data"
    if not data_dir.exists():
        return []
    return [name for name in META_TYPES if (data_dir / name).exists()]


def stream_file_names(model_dir: Path) -> list[str]:
    stream_dir = model_dir / "stream"
    if not stream_dir.exists():
        return []
    return [item.name.lower() for item in stream_dir.rglob("*") if item.is_file()]


def resource_model_names(model_dir: Path) -> list[str]:
    meta_path = model_dir / "data" / "vehicles.meta"
    if not meta_path.exists():
        return []
    root = parse_xml(meta_path)
    if root is None:
        return []
    names = [text_or_empty(item, "modelName") for item in root.findall(".//InitDatas/Item")]
    return [name for name in names if name]


def ensure_model_manifest(model_dir: Path) -> None:
    if (model_dir / "fxmanifest.lua").exists():
        return

    existing = model_dir / "__resource.lua"
    # nadpisujemy tylko manifesty wygenerowane przez ten skrypt, reczne zostawiamy
    if existing.exists() and not read_text_lossy(existing).startswith(GENERATED_MANIFEST_HEADER):
        return

    data_files = data_file_names(model_dir)

    lines = [GENERATED_MANIFEST_HEADER, ""]

    if data_files:
        lines.append("files {")
        for name in data_files:
            lines.append(f"    'data/{name}',")
        lines.append("}")
        lines.append("")
        for name in data_files:
            lines.append(f"data_file '{META_TYPES[name]}' 'data/{name}'")
        lines.append("")

    write_text(model_dir / "__resource.lua", "\n".join(lines))


def collect_vehicle_resources() -> list[tuple[str, str]]:
    resources: list[tuple[str, str]] = []

    for raw_brand_dir in sorted(ADDON_DIR.iterdir(), key=lambda item: item.name.lower()):
        if not raw_brand_dir.is_dir() or raw_brand_dir.name in SKIP_FOLDERS:
            continue
        if raw_brand_dir.name.startswith("_"):
            continue

        if not any(child.is_dir() and model_looks_like_vehicle(child) for child in raw_brand_dir.iterdir()):
            continue  # nie folder marki (np. docs) - zostawiamy w spokoju

        brand_dir = merge_or_rename_brand_folder(raw_brand_dir)
        if brand_dir.name in SKIP_FOLDERS or brand_dir.name.startswith("_"):
            continue

        for model_dir in sorted(brand_dir.iterdir(), key=lambda item: item.name.lower()):
            if not model_dir.is_dir() or model_dir.name.startswith("_"):
                continue
            if not model_looks_like_vehicle(model_dir):
                continue

            ensure_model_manifest(model_dir)

            brand = normalize_brand_name(brand_dir.name)
            streamed = stream_file_names(model_dir)
            datas = data_file_names(model_dir)
            if not streamed and not datas:
                warn(f"Pomijam {brand}/{model_dir.name}: pusty stream/ i zero plikow .meta")
                continue

            models = resource_model_names(model_dir)
            if not models:
                warn(f"{brand}/{model_dir.name}: brak vehicles.meta lub modelName")
            for model in models:
                if not streamed:
                    warn(f"{brand}/{model_dir.name}: model {model} nie ma stream/ - auto nie zaspawnuje")
                elif f"{model.lower()}.yft" not in streamed:
                    warn(f"{brand}/{model_dir.name}: brak {model}.yft w stream/")

            RESOURCE_MODELS[model_dir.name] = models
            resources.append((brand, model_dir.name))

    return resources


def collect_addon_qb_core_vehicles(resources: list[tuple[str, str]]) -> list[dict[str, str | int]]:
    vehicles: list[dict[str, str | int]] = []
    seen_models: set[str] = set()

    for brand, resource_name in sorted(resources, key=lambda item: (item[0].lower(), item[1].lower())):
        meta_path = ADDON_DIR / f"[{brand}]" / resource_name / "data" / "vehicles.meta"
        if not meta_path.exists():
            continue

        for vehicle in parse_vehicle_meta(meta_path, brand):
            model = str(vehicle["model"]).lower()
            if model in seen_models:
                continue
            seen_models.add(model)
            vehicles.append(vehicle)

    return vehicles


def write_vehicles_cfg(resources: list[tuple[str, str]]) -> None:
    seen: dict[str, str] = {}
    duplicates: list[str] = []

    for brand, resource_name in resources:
        if resource_name in seen:
            duplicates.append(f"{resource_name} ({seen[resource_name]} and {brand})")
        seen[resource_name] = brand

    if duplicates:
        duplicate_list = ", ".join(sorted(duplicates))
        raise RuntimeError(f"Duplicate vehicle resource names found: {duplicate_list}")

    lines = [
        "# Auto-generated by generate_vehicle_resources.py.",
        "# Do not edit this file manually. Add cars under resources/[addon]/[brand]/model and run the generator.",
        "",
    ]

    current_brand = None
    for brand, resource_name in sorted(resources, key=lambda item: (item[0].lower(), item[1].lower())):
        if brand != current_brand:
            if current_brand is not None:
                lines.append("")
            lines.append(f"# {brand}")
            current_brand = brand
        lines.append(f"ensure {resource_name}")

    lines.append("")
    write_text(VEHICLES_CFG, "\n".join(lines))


def write_vmenu_addons(resources: list[tuple[str, str]]) -> None:
    if not VMENU_ADDONS_JSON.exists():
        return

    data = json.loads(VMENU_ADDONS_JSON.read_text(encoding="utf-8-sig"))
    models = {model for _, resource_name in resources for model in RESOURCE_MODELS.get(resource_name, [])}
    data["vehicles"] = sorted(models, key=str.lower)

    VMENU_ADDONS_JSON.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def strip_generated_qb_core_block(content: str) -> str:
    pattern = re.compile(
        rf"\n{re.escape(GENERATED_QB_CORE_BEGIN)}.*?{re.escape(GENERATED_QB_CORE_END)}\n",
        re.DOTALL,
    )
    return pattern.sub("\n", content)


def existing_qb_core_models(content: str) -> set[str]:
    content = strip_generated_qb_core_block(content)
    return set(re.findall(r"\[['\"]model['\"]\]\s*=\s*['\"]([^'\"]+)['\"]", content))


def format_qb_core_vehicle(vehicle: dict[str, str | int]) -> str:
    return (
        f"    {{['model'] = '{lua_quote(str(vehicle['model']))}', "
        f"['name'] = '{lua_quote(str(vehicle['name']))}', "
        f"['brand'] = '{lua_quote(str(vehicle['brand']))}', "
        f"['price'] = {int(vehicle['price'])}, "
        f"['categoryLabel'] = '{lua_quote(str(vehicle['categoryLabel']))}', "
        f"['shop'] = '{lua_quote(str(vehicle['shop']))}'}},"
    )


def write_qb_core_addon_vehicles(addon_vehicles: list[dict[str, str | int]]) -> None:
    if not QB_CORE_VEHICLES_LUA.exists():
        return

    original = read_text_lossy(QB_CORE_VEHICLES_LUA)
    without_generated = strip_generated_qb_core_block(original)
    existing_models = existing_qb_core_models(without_generated)
    existing_lower = {model.lower() for model in existing_models}
    missing_vehicles = [
        vehicle
        for vehicle in addon_vehicles
        if str(vehicle["model"]).lower() not in existing_lower
    ]

    block_lines = [
        GENERATED_QB_CORE_BEGIN,
        "    -- Auto-generated by resources/[addon]/generate_vehicle_resources.py.",
        "    -- Existing manual vehicle entries are left untouched.",
    ]
    block_lines.extend(format_qb_core_vehicle(vehicle) for vehicle in missing_vehicles)
    block_lines.append(GENERATED_QB_CORE_END)

    # pierwsza klamra w kolumnie 0 po "local Vehicles = {" zamyka tabele
    table_start = without_generated.find("local Vehicles = {")
    if table_start == -1:
        raise RuntimeError(f"Could not find Vehicles table in {QB_CORE_VEHICLES_LUA}")
    insert_at = without_generated.find(chr(10) + "}", table_start)
    if insert_at == -1:
        raise RuntimeError(f"Could not find end of Vehicles table in {QB_CORE_VEHICLES_LUA}")

    updated = without_generated[:insert_at] + "\n" + "\n".join(block_lines) + without_generated[insert_at:]
    write_text(QB_CORE_VEHICLES_LUA, updated)


def validate_generation(resources: list[tuple[str, str]]) -> list[str]:
    errors: list[str] = []

    if not VEHICLES_CFG.exists():
        errors.append(f"Missing generated config: {VEHICLES_CFG}")
        return errors

    cfg_lines = set(VEHICLES_CFG.read_text(encoding="utf-8").splitlines())
    vmenu_vehicles = set()
    if VMENU_ADDONS_JSON.exists():
        vmenu_data = json.loads(VMENU_ADDONS_JSON.read_text(encoding="utf-8-sig"))
        vmenu_vehicles = set(vmenu_data.get("vehicles", []))

    for brand, resource_name in resources:
        model_dir = ADDON_DIR / f"[{brand}]" / resource_name

        if f"ensure {resource_name}" not in cfg_lines:
            errors.append(f"Missing ensure entry for {brand}/{resource_name}")
        if not model_has_manifest(model_dir):
            errors.append(f"Missing manifest for {brand}/{resource_name}")
        if VMENU_ADDONS_JSON.exists():
            for model in RESOURCE_MODELS.get(resource_name, []):
                if model not in vmenu_vehicles:
                    errors.append(f"Missing vMenu addon vehicle {model} ({brand}/{resource_name})")

    return errors


def main() -> int:
    if not ADDON_DIR.exists():
        print(f"Missing addon directory: {ADDON_DIR}", file=sys.stderr)
        print("status=500")
        return 1

    try:
        resources = collect_vehicle_resources()
        write_vehicles_cfg(resources)
        write_vmenu_addons(resources)
        addon_vehicles = collect_addon_qb_core_vehicles(resources)
        write_qb_core_addon_vehicles(addon_vehicles)
        validation_errors = validate_generation(resources)
    except Exception as exc:
        print(f"Vehicle resource generation failed: {exc}", file=sys.stderr)
        print("status=500")
        return 1

    if WARNINGS:
        print(f"Ostrzezenia ({len(WARNINGS)}):", file=sys.stderr)
        for message in WARNINGS:
            print(f"- {message}", file=sys.stderr)

    if validation_errors:
        print("Vehicle resource validation failed:", file=sys.stderr)
        for error in validation_errors:
            print(f"- {error}", file=sys.stderr)
        print("status=500")
        return 1

    print(f"Generated {VEHICLES_CFG} with {len(resources)} vehicle resources.")
    print(f"Updated {QB_CORE_VEHICLES_LUA} with addon vehicle metadata.")
    print(f"status=200 vehicles={len(resources)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
