#!/usr/bin/env python3
import pathlib
import re
import sys

incdir = pathlib.Path(sys.argv[1])
cfg = incdir / "sundials" / "sundials_config.h"

if not cfg.exists():
    raise SystemExit(f"Could not find {cfg}")

txt = cfg.read_text(encoding="utf-8", errors="ignore")

m = re.search(
    r'#define\s+SUNDIALS_(?:PACKAGE_)?VERSION\s+"([^"]+)"',
    txt,
)
if not m:
    raise SystemExit("Could not detect SUNDIALS version from sundials_config.h")

version = m.group(1).split("-dev")[0]
parts = version.split(".")
tup = tuple(int(x) for x in parts[:3])

vector_size = "unknown"
if re.search(r"^#define\s+SUNDIALS_INT64_T\b", txt, re.M):
    vector_size = "64"
elif re.search(r"^#define\s+SUNDIALS_INT32_T\b", txt, re.M):
    vector_size = "32"

with_superlu = bool(re.search(r"^#define\s+SUNDIALS_SUPERLUMT\b", txt, re.M))
cvode_rtol_vec = bool(re.search(r"^#define\s+SUNDIALS_CVODE_RTOL_VEC\b", txt, re.M))

print(f"version={version}")
print(f"version_tuple=({tup[0]}, {tup[1]}, {tup[2]})")
print(f"major={tup[0]}")
print(f"vector_size={vector_size}")
print(f"with_superlu={'True' if with_superlu else 'False'}")
print(f"cvode_rtol_vec={'True' if cvode_rtol_vec else 'False'}")
