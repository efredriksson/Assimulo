#!/usr/bin/env python3
"""Run numpy.f2py from a specified working directory.

Workaround for a distutils bug on Windows: when f2py -c runs with its CWD on
a different drive from the source files, distutils tries to create the bare
drive letter (e.g. 'C:') as a directory and fails with "Access is denied".
Changing to the project source root first keeps everything on the same drive.

Usage: python tools/f2py_build.py <workdir> [f2py args...]
"""
import os
import sys
import subprocess

if __name__ == '__main__':
    workdir = sys.argv[1]
    f2py_args = sys.argv[2:]
    os.chdir(workdir)
    result = subprocess.run(
        [sys.executable, '-m', 'numpy.f2py'] + f2py_args,
        check=False,
    )
    sys.exit(result.returncode)
