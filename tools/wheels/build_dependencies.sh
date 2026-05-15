#!/usr/bin/env bash
# tools/wheels/build_dependencies.sh
# Builds SuperLU_MT and SUNDIALS from source into /usr.
# Runs inside quay.io/pypa/manylinux_2_28_x86_64 (AlmaLinux 8, dnf available).
# Used by both Dockerfile.manylinux (local testing) and cibuildwheel (CI).
set -eux

# Ensure standard system paths are in PATH (cibuildwheel's before-all
# environment may have a minimal PATH that omits /usr/bin).
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:${PATH}}"

SUPERLU_VERSION="4.0.1"
SUNDIALS_VERSION="2.7.0-3"
NPROC=$(nproc)

# --- System packages ---
yum install -y \
    gcc-gfortran \
    lapack-devel \
    lapack-static \
    blas-devel \
    openblas-devel \
    cmake
yum clean all

# cmake 4.x rejects SUNDIALS 2.7.0 old CMakeLists.txt. The yum cmake above installs
# cmake 3.x at /usr/bin/cmake; remove any cmake 4.x that may be at /usr/local/bin.
rm -f /usr/local/bin/cmake
cmake --version


# --- SuperLU_MT ---
curl -fSsL \
    "https://github.com/xiaoyeli/superlu_mt/archive/refs/tags/v${SUPERLU_VERSION}.tar.gz" \
    | tar xz -C /tmp

cmake -S "/tmp/superlu_mt-${SUPERLU_VERSION}" \
      -B "/tmp/superlu_mt-${SUPERLU_VERSION}/build" \
      -Denable_examples=OFF \
      -Denable_tests=OFF \
      -DPLAT="_OPENMP" \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DSUPERLUMT_INSTALL_INCLUDEDIR=include

make -C "/tmp/superlu_mt-${SUPERLU_VERSION}/build" -j"${NPROC}"
make -C "/tmp/superlu_mt-${SUPERLU_VERSION}/build" install
rm -rf "/tmp/superlu_mt-${SUPERLU_VERSION}"

# --- SUNDIALS (Modelon community fork) ---
# Embed SuperLU+BLAS into the shared libs so the .so files are self-contained.
git clone --depth 1 -b "v${SUNDIALS_VERSION}" \
    https://github.com/modelon-community/sundials /tmp/sundials

echo "target_link_libraries(sundials_cvodes_shared lapack blas superlu_mt_OPENMP)" \
    >> /tmp/sundials/src/cvodes/CMakeLists.txt
echo "target_link_libraries(sundials_idas_shared lapack blas superlu_mt_OPENMP)" \
    >> /tmp/sundials/src/idas/CMakeLists.txt
echo "target_link_libraries(sundials_kinsol_shared lapack blas superlu_mt_OPENMP)" \
    >> /tmp/sundials/src/kinsol/CMakeLists.txt

cmake -S /tmp/sundials -B /tmp/sundials/build \
    -DSUPERLUMT_INCLUDE_DIR=/usr/include \
    -DSUPERLUMT_LIBRARY=/usr/lib/libsuperlu_mt_OPENMP.a \
    -DSUPERLUMT_THREAD_TYPE=OpenMP \
    -DSUPERLUMT_ENABLE=ON \
    -DLAPACK_ENABLE=ON \
    -DEXAMPLES_ENABLE=OFF \
    -DEXAMPLES_ENABLE_C=OFF \
    -DBUILD_STATIC_LIBS=ON \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib

make -C /tmp/sundials/build -j"${NPROC}"
make -C /tmp/sundials/build install
rm -rf /tmp/sundials
