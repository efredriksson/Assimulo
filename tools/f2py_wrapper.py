#!/usr/bin/env python3
"""Generate f2py C/Fortran wrapper files (no compilation).

Called by meson custom_target. Produces in <outdir>:
  <modname>module.c           - C/Python glue
  <modname>-f2pywrappers.f    - Fortran 77 shims (placeholder if f2py emits none)
  <modname>-f2pywrappers2.f90 - Fortran 90 shims (radar5 only; placeholder otherwise)

Usage: python3 f2py_wrapper.py <outdir> <modname> <pyf_file>
"""

import subprocess
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <outdir> <modname> <pyf_file>", file=sys.stderr)
        sys.exit(1)

    outdir = Path(sys.argv[1]).resolve()
    modname = sys.argv[2]
    pyf = Path(sys.argv[3]).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    # Mirror what run_compile does for .pyf + meson backend (f2py2e.py:734):
    # invoke f2py with just the .pyf (no -m, no --build-dir) and let the .pyf's
    # own `python module <name>` declaration drive the output filename. Passing
    # -m here would force every `python module` block in the .pyf to share the
    # same <modname>module.c output, last write wins.
    subprocess.run(
        [sys.executable, "-m", "numpy.f2py", str(pyf)],
        cwd=outdir,
        check=True,
    )

    # meson custom_target declares fixed outputs per solver; create empty
    # placeholders for the wrapper files f2py chose not to emit for this .pyf.
    for name in (f"{modname}-f2pywrappers.f", f"{modname}-f2pywrappers2.f90"):
        path = outdir / name
        if not path.exists():
            path.write_text("! f2py placeholder\n")


if __name__ == "__main__":
    main()
