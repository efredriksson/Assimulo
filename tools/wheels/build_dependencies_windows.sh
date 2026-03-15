#!/usr/bin/env bash
# tools/wheels/build_dependencies_windows.sh
# Builds SUNDIALS from source using MSYS2 UCRT64 toolchain.
# Run from an MSYS2 UCRT64 shell (shell: msys2 {0} in GHA).
# Installs to /c/deps (= C:\deps on Windows).
# No SuperLU (first iteration — CVODES/IDAS/KINSOL don't require it).
set -eux

SUNDIALS_VERSION="2.7.0-3"
INSTALL_PREFIX="/c/deps"
NPROC=$(nproc 2>/dev/null || echo 4)

mkdir -p "${INSTALL_PREFIX}/bin" "${INSTALL_PREFIX}/lib"

git clone --depth 1 -b "v${SUNDIALS_VERSION}" \
    https://github.com/modelon-community/sundials /tmp/sundials

cmake -S /tmp/sundials -B /tmp/sundials/build \
    -G Ninja \
    -DSUPERLUMT_ENABLE=OFF \
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

# --- OpenBLAS (provides BLAS and LAPACK for glimda) ---
pacman -S --noconfirm mingw-w64-ucrt-x86_64-openblas
cp /ucrt64/lib/libopenblas.dll.a "${INSTALL_PREFIX}/lib/"
cp /ucrt64/bin/libopenblas.dll   "${INSTALL_PREFIX}/bin/"
