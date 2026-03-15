#!/usr/bin/env python3
"""Generate f2py C/Fortran wrapper files without compiling.

Called by meson custom_target. Produces:
  <modname>module.c           — C/Python glue code
  <modname>-f2pywrappers.f    — Fortran 77 calling-convention shims
  <modname>-f2pywrappers2.f90 — Fortran 90 shims (radar5 only)

f2py's run_compile() is called directly (not via subprocess) so that the
MesonBackend monkey-patches apply in the same process. On Windows, where
subprocess without shell=True can't find .cmd files, _run_subprocess_command
is patched to add shell=True so cmd.exe resolves our fake meson.cmd via PATHEXT.

Usage: python3 f2py_wrapper.py <outdir> <modname> <pyf_file>
"""

import os
import sys
import subprocess
import tempfile
from pathlib import Path


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <outdir> <modname> <pyf_file>", file=sys.stderr)
        sys.exit(1)

    outdir  = Path(sys.argv[1]).resolve()
    modname = sys.argv[2]
    pyf     = Path(sys.argv[3]).resolve()

    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)

        # Place a no-op fake meson on PATH so f2py's -c compilation step exits 0.
        if sys.platform == "win32":
            (tmpdir / "meson.cmd").write_text("@python -c \"import sys; sys.exit(0)\" %*\n")
            # CreateProcess (subprocess without shell=True) only finds .exe, not
            # .cmd. Patch f2py's backend to use shell=True so cmd.exe finds
            # meson.cmd. This must be done in-process — patching in a subprocess
            # parent has no effect on the child.
            from numpy.f2py._backends._meson import MesonBackend
            MesonBackend._run_subprocess_command = (
                lambda self, cmd, cwd: subprocess.run(cmd, cwd=cwd, check=True, shell=True)
            )
        else:
            meson = tmpdir / "meson"
            meson.write_text("#!/usr/bin/env python3\nimport sys; sys.exit(0)\n")
            meson.chmod(0o755)

        os.environ["PATH"] = str(tmpdir) + os.pathsep + os.environ.get("PATH", "")

        # Run f2py in tmpdir so _prepare_sources can copy generated files from
        # CWD (tmpdir) to --build-dir (outdir) without a SameFileError.
        os.chdir(tmpdir)
        sys.argv = ["f2py", "-m", modname, "--build-dir", str(outdir),
                    "--backend", "meson", "-c", str(pyf)]
        from numpy.f2py.f2py2e import run_compile
        try:
            run_compile()
        except SystemExit:
            pass

    # Create placeholder files for any wrapper files f2py didn't generate.
    for name, content in [
        (f"{modname}-f2pywrappers.f",    "! f2py placeholder\n"),
        (f"{modname}-f2pywrappers2.f90", "! f2py placeholder\n"),
    ]:
        path = outdir / name
        if not path.exists():
            path.write_text(content)


if __name__ == "__main__":
    main()
