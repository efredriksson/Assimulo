#!/usr/bin/env python3
"""Run numpy.f2py from a specified working directory.

Workaround for a distutils cross-drive bug on Windows: f2py's build_src step
generates C wrapper files using tempfile.gettempdir() (typically C:\\...\\Temp).
When distutils then processes those C files alongside source files on D:, it
tries to create a bare drive letter ('C:') as a directory and fails.

Fix: redirect TMP/TEMP/TMPDIR to a local directory under the source root so
that all generated files land on the same drive as the build artifacts.

Usage: python tools/f2py_build.py <workdir> [f2py args...]
"""
import os
import sys
import subprocess

if __name__ == '__main__':
    workdir = sys.argv[1]
    f2py_args = sys.argv[2:]

    os.chdir(workdir)

    # Keep generated C wrappers on the same drive as source + build dirs.
    tmp = os.path.join(workdir, 'build', '_f2py_tmp')
    os.makedirs(tmp, exist_ok=True)
    env = os.environ.copy()
    env.update({'TMP': tmp, 'TEMP': tmp, 'TMPDIR': tmp})

    result = subprocess.run(
        [sys.executable, '-m', 'numpy.f2py'] + f2py_args,
        env=env,
        check=False,
    )
    sys.exit(result.returncode)
