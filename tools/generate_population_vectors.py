"""Independent integer remainder oracle. Tests only; no gameplay parameters."""
from pathlib import Path
import random
import argparse

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rng = random.Random(0x48544506)
    maximum = (1 << 64) - 1
    edges = [0, 1, (1 << 32)-1, 1 << 32, (1 << 53)-1, 1 << 53,
             (1 << 53)+1, (1 << 63)-1, 1 << 63, maximum]
    pairs = [(a,b) for a in edges for b in edges if b]
    pairs += [(rng.getrandbits(64), rng.getrandbits(64) or 1) for _ in range(400)]
    text = "-- Python int oracle, seed 0x48544506; TEST ONLY.\nreturn {\n"
    text += "".join(f'\t{{"{a}","{b}","{a % b}"}},\n' for a,b in pairs)
    text += "}\n"
    dest = ROOT / "tests/hatching/population_vectors.luau"
    if args.check:
        assert dest.read_bytes() == text.encode(), "Population oracle is stale"
    else:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text, encoding="utf-8", newline="\n")
    print(f"Population oracle {'check ' if args.check else ''}PASS: {len(pairs)} exact cases")


if __name__ == "__main__":
    main()
