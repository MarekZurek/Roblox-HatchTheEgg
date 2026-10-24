"""Independent JSON -> binary64-bit expectations (not imported by catalog generator).

Lune serde may parse decimal JSON one ULP differently, so it is not a bit oracle.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    bits, hashes = {}, {}

    def walk(value, path):
        if isinstance(value, dict):
            for k, v in value.items():
                walk(v, f"{path}.{k}")
        elif isinstance(value, list):
            for i, v in enumerate(value, 1):
                walk(v, f"{path}.{i}")
        elif isinstance(value, (int, float)) and not isinstance(value, bool):
            bits[path] = struct.pack("<d", float(value)).hex()

    for name in ("research", "infrastructure"):
        path = ROOT / f"docs/reference_data/{name}.json"
        hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        data = json.loads(path.read_text(encoding="utf-8"))
        if name == "research":
            walk(data["tierThresholds"], "thresholds")
            for row in data["common"]:
                for field in ("tier_raw", "maxLevel", "prices", "effectsByLevel"):
                    walk(row[field], row["id"] + "." + field)
            for row in data["epic"]:
                for field in ("tier_raw", "maxLevel", "prices", "effectsByLevel"):
                    walk(row[field], "epic." + row["id"] + "." + field)
        else:
            for i, row in enumerate(data["eggs"]):
                for field in ("index", "value"):
                    walk(row[field], f"eggs.{i}.{field}")
            for group in ("habitats", "vehicles"):
                for i, row in enumerate(data[group]):
                    for field in ("index", "capacity", "prices"):
                        walk(row[field], f"{group}.{i}.{field}")
    content = json.dumps({"sourceSha256": hashes, "bits": bits}, indent=2, sort_keys=True) + "\n"
    target = Path(__file__).with_name("numeric_bits.json")
    if args.check:
        if target.read_bytes() != content.encode():
            raise SystemExit("Independent numeric oracle stale")
        print("Independent catalog oracle check PASS")
    else:
        target.write_bytes(content.encode())


if __name__ == "__main__":
    main()
