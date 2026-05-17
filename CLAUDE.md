# Assimulo

Python/Cython library providing a unified interface to ODE and DAE solvers. Solvers are implemented in Fortran and C; the Python/Cython layer wraps them for use from Python.

## Architecture

- `src/` - Cython source (`.pyx`/`.pxd`) for the core library and solver wrappers
  - `problem.pyx` - base `Explicit_Problem` / `Implicit_Problem` classes
  - `explicit_ode.pyx`, `implicit_ode.pyx` - solver base classes
  - `solvers/sundials.pyx` - CVode (explicit ODE) and IDA (implicit DAE) via SUNDIALS
  - `solvers/radau5.pyx`, `solvers/odepack.py`, etc. - Python/Cython wrappers for Fortran/C solvers
  - `lib/` - Cython include files for SUNDIALS callbacks and constants
- `thirdparty/` - Fortran source for hairer (Radau5, Dopri5, Rodas), dasp3, glimda, odassl, odepack, kvaernoe. **Do not edit unless specifically asked.**
- `tests/` - pytest test suite (`pytest` from repo root)
- `examples/` - usage examples per solver

## Build

Build backend is `meson-python`; options in `meson.options`. All targets run inside Docker.

```
make build        # full install into .venv
make build-dev    # incremental editable install (keeps builddir/)
make check-meson.build  # validate meson config without building
```

Dependencies: Python ≥ 3.11, NumPy ≥ 2.1, SciPy ≥ 1.14, Cython ≥ 3.0.7, SUNDIALS v2.7.0. Linux requires `libopenblas-dev`; Windows links BLAS statically.

Fortran solvers are wrapped via `tools/f2py_wrapper.py` (generates C glue from `.pyf` files).

## Testing

```
pytest
```

## Key constraints

- **Do not modify files under `thirdparty/`** (Fortran solver sources) unless explicitly asked.
- The C file `src/ode_event_locator.c` is a vendored C implementation - treat it the same way.
- After editing any `.pyx` file, the Cython extension must be rebuilt before changes take effect.
- **Always use `make build` for rebuilds.** Never copy `.so` files, `.py` files, or other build artifacts manually into site-packages as a shortcut - always do a full rebuild so the installed package is consistent with the source.
