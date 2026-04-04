#!/usr/bin/env python3
"""
check_coverage.py — enforces code coverage thresholds from xcresult bundle.

Usage:
    python3 scripts/check_coverage.py <xcresult_bundle>

Exit codes:
    0 = all thresholds passed
    1 = one or more thresholds failed
"""
import subprocess
import json
import sys
import os
import re

# ── Thresholds ─────────────────────────────────────────────────────────

THRESHOLDS = {
    # Target-level
    "DavyWhisper.app": 0.15,       # Phase 3 baseline: 16.1% measured 2026-04-04
}


CATEGORY_THRESHOLDS = {
    # Exclude plugins + vendor from these
    # Phase 3: measured 2026-04-04 after ViewModel extraction + ViewModel tests
    "Services (core)":   0.42,       # Phase 3: 44.1% measured → target 60%
    "ViewModels":        0.40,       # Phase 3: 41.5% measured → target 55%
    "Models":           0.70,       # Phase 3: 72.5% measured → target 80%
    "HTTP Server":       0.61,       # Phase 3: 62.1% measured → target 75%
}

LOW_COVERAGE_WARN = 0.20           # warn if any file < 20%

# Paths to exclude from "app code" coverage
EXCLUDE_PREFIXES = [
    "Plugins/",
]

# Category filter: maps category name → paths that should be INCLUDED in that category
CATEGORY_INCLUDE = {
    "Services (core)": [
        "DavyWhisper/Services/",
    ],
    "ViewModels": [
        "DavyWhisper/ViewModels/",
    ],
    "Models": [
        "DavyWhisper/Models/",
    ],
    "HTTP Server": [
        "DavyWhisper/Services/HTTPServer/",
    ],
}


def run_xccov(args: list[str], xcresult: str) -> str:
    """Run xcrun xccov with the given args appended to the xcresult path."""
    cmd = ["xcrun", "xccov"] + args + [xcresult]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return result.stdout + result.stderr


def get_targets(xcresult: str) -> dict[str, float]:
    """Return {target_name: coverage_pct} for targets in the bundle."""
    output = run_xccov(["view", "--report", "--only-targets", "--json"], xcresult)
    try:
        data = json.loads(output)
    except json.JSONDecodeError:
        print(f"Warning: could not parse targets JSON: {output[:200]}")
        return {}

    # xccov --only-targets returns a list directly (not a dict with "targets" key)
    targets = {}
    for t in data if isinstance(data, list) else data.get("targets", []):
        name = t.get("name", "unknown")
        cov = t.get("lineCoverage", 0.0)
        targets[name] = cov
    return targets


def get_file_coverage(xcresult: str, target: str) -> list[dict]:
    """Return list of {path, lineCount, executedLineCount, lineCoverage} for a target."""
    output = run_xccov([
        "view", "--report",
        "--files-for-target", target,
        "--json"
    ], xcresult)
    try:
        data = json.loads(output)
    except json.JSONDecodeError:
        print(f"Warning: could not parse files JSON")
        return []
    # xccov --files-for-target returns a list with one dict wrapper containing "files" key
    if isinstance(data, list) and data and isinstance(data[0], dict) and "files" in data[0]:
        return data[0]["files"]
    return data if isinstance(data, list) else data.get("files", [])


def category_coverage(files: list[dict], include_prefixes: list[str]) -> tuple[float, int, int]:
    """Compute coverage % for files matching any include_prefix."""
    included = [
        f for f in files
        if any(p in f.get("path", "") for p in include_prefixes)
    ]
    total = sum(f.get("executableLines", 0) for f in included)
    covered = sum(f.get("coveredLines", 0) for f in included)
    pct = (covered / total * 100) if total > 0 else 0.0
    return pct, covered, total


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/check_coverage.py <xcresult_bundle>")
        sys.exit(1)

    xcresult = sys.argv[1]
    # Accept a path or directory; xcrun needs .xcresult extension
    # Normalize: resolve directory / alternate .xcresult name, then ensure .xcresult suffix
    if os.path.isdir(xcresult):
        if not xcresult.endswith(".xcresult"):
            alt = xcresult + ".xcresult"
            if os.path.isdir(alt):
                xcresult = alt
        # xcrun needs .xcresult suffix
        if not xcresult.endswith(".xcresult"):
            xcresult = xcresult + ".xcresult"
    elif os.path.exists(xcresult):
        pass
    else:
        print(f"ERROR: {xcresult} not found")
        sys.exit(1)

    # xcresult is now guaranteed to be a valid path
    resolved_xcresult = xcresult

    print("=== Coverage Thresholds ===\n")

    failed = []

    # ── Target-level checks ────────────────────────────────────────────
    print("--- Target Coverage ---")
    targets = get_targets(resolved_xcresult)
    for name, cov_pct in targets.items():
        if name in THRESHOLDS:
            thresh = THRESHOLDS[name] * 100
            if cov_pct * 100 < thresh:
                print(f"  ✗ {name}: {cov_pct*100:.1f}%  (threshold: {thresh:.0f}%)")
                failed.append(name)
            else:
                print(f"  ✓ {name}: {cov_pct*100:.1f}%  (threshold: {thresh:.0f}%)")

    # ── Category checks (DavyWhisper.app, excluding plugins) ──────────
    if "DavyWhisper.app" in targets:
        print("\n--- Category Coverage (excl. plugins & vendor) ---")
        files = get_file_coverage(resolved_xcresult, "DavyWhisper.app")

        # Filter out plugins
        app_files = [f for f in files if not any(p in f.get("path", "") for p in EXCLUDE_PREFIXES)]

        for cat_name, thresholds in CATEGORY_THRESHOLDS.items():
            includes = CATEGORY_INCLUDE.get(cat_name, [])
            included = [f for f in app_files if any(p in f.get("path", "") for p in includes)]
            total = sum(f.get("executableLines", 0) for f in included)
            covered = sum(f.get("coveredLines", 0) for f in included)
            pct = (covered / total * 100) if total > 0 else 0.0
            thresh_pct = thresholds * 100

            if pct < thresh_pct:
                print(f"  ✗ {cat_name}: {pct:.1f}%  (threshold: {thresh_pct:.0f}%, files: {covered}/{total})")
                failed.append(cat_name)
            else:
                print(f"  ✓ {cat_name}: {pct:.1f}%  (threshold: {thresh_pct:.0f}%, files: {covered}/{total})")

        # ── Low-coverage file warnings ─────────────────────────────────
        print("\n--- Low-Coverage Files (< 20%) ---")
        low = [
            f for f in app_files
            if f.get("lineCoverage", 1.0) < LOW_COVERAGE_WARN
            and f.get("executableLines", 0) > 50  # only warn for files > 50 lines
        ]
        low.sort(key=lambda f: f.get("lineCoverage", 1.0))
        if low:
            for f in low[:15]:
                path = f.get("path", "")
                short = os.path.basename(path)
                pct = f.get("lineCoverage", 0.0) * 100
                lines = f.get("executableLines", 0)
                print(f"  ⚠  {short}: {pct:.1f}%  ({lines} lines)")
        else:
            print("  (none)")

    # ── Summary ────────────────────────────────────────────────────────
    print()
    if failed:
        print("=== COVERAGE GATE FAILED ===")
        print(f"Failed: {', '.join(failed)}")
        sys.exit(1)
    else:
        print("=== COVERAGE GATE PASSED ===")
        sys.exit(0)


if __name__ == "__main__":
    main()
