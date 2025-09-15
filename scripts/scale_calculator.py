#!/usr/bin/env python3
import sys, json, math, subprocess

def nearest_clean_scale(w, h, s):
    # Same method as your inline snippet
    G = math.gcd(w * 120, h * 120)
    best = None
    bestd = 1e9
    d = 1
    while d * d <= G:
        if G % d == 0:
            for N in (d, G // d):
                val = N / 120.0
                dlt = abs(val - s)
                if dlt < bestd - 1e-12:
                    best, bestd = val, dlt
        d += 1
    return best

def main():
    if len(sys.argv) < 3:
        print("usage: scale_helper.py <monitor_name> <scale1> [<scale2> ...]", file=sys.stderr)
        sys.exit(1)

    mon_name = sys.argv[1]
    scales = [float(x) for x in sys.argv[2:]]

    # Read monitors from Hyprland and pick the named one
    mons = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"]))
    mon = next((m for m in mons if m.get("name") == mon_name), None)
    if not mon:
        print(f"monitor '{mon_name}' not found", file=sys.stderr)
        sys.exit(2)

    w, h = int(mon["width"]), int(mon["height"])

    for s in scales:
        v = nearest_clean_scale(w, h, s)
        if abs(v - s) < 1e-9:
            label = f"{s:.2f} (clean)"
        else:
            label = f"{s:.2f} → {v:.6f}"
        # Output "<label>\t<apply_value>" so Bash can map selection -> value
        print(f"{label}\t{v:.6f}")

if __name__ == "__main__":
    main()

