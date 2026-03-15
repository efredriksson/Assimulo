#!/usr/bin/env python3
"""Generate f2py C/Fortran wrapper files without compiling.

Called by meson custom_target. Produces the wrapper files declared in the
fortran_solvers 'outputs' list in meson.build — typically:
  <modname>module.c           — C/Python glue code
  <modname>-f2pywrappers.f    — Fortran 77 calling-convention shims
  <modname>-f2pywrappers2.f90 — Fortran 90 shims (radar5 only)

Only the .pyf interface file is passed to f2py; Fortran sources are compiled by
meson/gfortran directly. f2py is run with -c --backend meson so it uses the
meson code path on all numpy versions (>=1.26). The non-c path has a regression
that generates empty modules when a .pyf contains 'interface  ! in :source'
block annotations (as odepack.pyf does). A no-op fake meson is put on PATH so
that the meson setup/compile steps that -c triggers are silently skipped. f2py
writes wrapper files directly to outdir via --build-dir so no copying is needed.

Usage: python3 f2py_wrapper.py <outdir> <modname> <pyf_file>
"""

import os
import sys
import subprocess
import tempfile
from pathlib import Path


def fake_meson_dir(tmpdir: Path) -> Path:
    """Write a no-op meson script to *tmpdir* and return it."""
    if sys.platform == "win32":
        meson = tmpdir / "meson.cmd"
        meson.write_text("@python -c \"import sys; sys.exit(0)\" %*\n")
    else:
        meson = tmpdir / "meson"
        meson.write_text("#!/usr/bin/env python3\nimport sys; sys.exit(0)\n")
        meson.chmod(0o755)

    return tmpdir


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <outdir> <modname> <pyf_file>", file=sys.stderr)
        sys.exit(1)

    outdir  = Path(sys.argv[1]).resolve()
    modname = sys.argv[2]
    pyf     = Path(sys.argv[3]).resolve()

    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        env = {**os.environ, "PATH": str(fake_meson_dir(tmpdir)) + os.pathsep + os.environ.get("PATH", "")}
        subprocess.run(
            [sys.executable, "-m", "numpy.f2py", "-m", modname, "--build-dir", outdir, "--backend", "meson", "-c", pyf],
            cwd=tmpdir,
            env=env,
            check=True,
        )


if __name__ == "__main__":
    main()
