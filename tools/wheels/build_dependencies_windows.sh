#!/usr/bin/env bash
# tools/wheels/build_dependencies_windows.sh
# Builds SuperLU_MT and SUNDIALS from source using MSYS2 UCRT64 toolchain.
# Run from an MSYS2 UCRT64 shell (shell: msys2 {0} in GHA).
# Installs to /c/deps (= C:\deps on Windows).
#
# OpenBLAS provides BLAS (and LAPACK, though Assimulo doesn't use SUNDIALS'
# CVLapack* APIs). SuperLU_MT + glimda link against the MSYS2 mingw-w64
# OpenBLAS shared library; delvewheel bundles libopenblas.dll into the wheel.
set -eux

SUPERLU_VERSION="4.0.1"
SUNDIALS_VERSION="2.7.0-3"
INSTALL_PREFIX="/c/deps"
NPROC=$(nproc 2>/dev/null || echo 4)

mkdir -p "${INSTALL_PREFIX}/bin" "${INSTALL_PREFIX}/lib" "${INSTALL_PREFIX}/include"

# --- OpenBLAS (shared) for SUNDIALS+SuperLU+glimda ---
pacman -S --noconfirm mingw-w64-ucrt-x86_64-openblas
# Stage the import lib + DLL into the same C:/deps tree we use for SUNDIALS,
# so meson's default_lib_candidates ([..., 'C:/deps/lib']) finds it and the
# delvewheel --add-path C:\deps\bin entry picks the DLL.
cp /ucrt64/lib/libopenblas.dll.a "${INSTALL_PREFIX}/lib/"
cp /ucrt64/bin/libopenblas.dll   "${INSTALL_PREFIX}/bin/"
OPENBLAS_LIB="${INSTALL_PREFIX}/lib/libopenblas.dll.a"

# Both SUNDIALS 2.7 and SuperLU_MT 4.0.1 use `cmake_minimum_required` values
# that the bundled MSYS2 cmake (>= 4.x) rejects. Export as an env var so it
# propagates to cmake's `try_compile` sub-invocations (the -D form does not).
export CMAKE_POLICY_VERSION_MINIMUM=3.5

# --- SuperLU_MT ---
curl -fSsL \
    "https://github.com/xiaoyeli/superlu_mt/archive/refs/tags/v${SUPERLU_VERSION}.tar.gz" \
    | tar xz -C /tmp

cmake -S "/tmp/superlu_mt-${SUPERLU_VERSION}" \
      -B "/tmp/superlu_mt-${SUPERLU_VERSION}/build" \
      -G Ninja \
      -Denable_examples=OFF \
      -Denable_tests=OFF \
      -DPLAT="_OPENMP" \
      -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DSUPERLUMT_INSTALL_INCLUDEDIR=include

cmake --build "/tmp/superlu_mt-${SUPERLU_VERSION}/build" --parallel "${NPROC}"
cmake --install "/tmp/superlu_mt-${SUPERLU_VERSION}/build"
rm -rf "/tmp/superlu_mt-${SUPERLU_VERSION}"

# --- SUNDIALS ---
# Embed SuperLU + OpenBLAS into the shared libs so the .dll files are
# self-contained. LAPACK_ENABLE=OFF because Assimulo doesn't call CVLapack*.
git clone --depth 1 -b "v${SUNDIALS_VERSION}" \
    https://github.com/modelon-community/sundials /tmp/sundials

# Use absolute paths in Windows form (C:/deps/...): /c/deps/lib is not on
# the mingw linker's default search path, and ninja interprets msys2-style
# /c/... paths as Unix paths that don't exist on Windows.
#
# All six SUNDIALS solver shared libs compile in a *_superlumt.c source file
# when SUPERLUMT_ENABLE=ON; each needs explicit linkage. On Linux this is
# masked by /usr/lib being on the default ld path, so it's only needed here.
SUPERLU_LIB_WIN=$(cygpath -m "${INSTALL_PREFIX}/lib/libsuperlu_mt_OPENMP.a")
OPENBLAS_LIB_WIN=$(cygpath -m "${OPENBLAS_LIB}")
for solver in cvode cvodes ida idas kinsol arkode; do
    echo "target_link_libraries(sundials_${solver}_shared ${SUPERLU_LIB_WIN} ${OPENBLAS_LIB_WIN})" \
        >> "/tmp/sundials/src/${solver}/CMakeLists.txt"
done

cmake -S /tmp/sundials -B /tmp/sundials/build \
    -G Ninja \
    -DSUPERLUMT_INCLUDE_DIR="${INSTALL_PREFIX}/include" \
    -DSUPERLUMT_LIBRARY="${INSTALL_PREFIX}/lib/libsuperlu_mt_OPENMP.a" \
    -DSUPERLUMT_BLAS_LIBRARIES="${OPENBLAS_LIB}" \
    -DSUPERLUMT_THREAD_TYPE=OpenMP \
    -DSUPERLUMT_ENABLE=ON \
    -DLAPACK_ENABLE=OFF \
    -DEXAMPLES_ENABLE=OFF \
    -DEXAMPLES_ENABLE_C=OFF \
    -DBUILD_STATIC_LIBS=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
    -DCMAKE_BUILD_TYPE=Release

cmake --build /tmp/sundials/build --parallel "${NPROC}"
cmake --install /tmp/sundials/build
rm -rf /tmp/sundials
