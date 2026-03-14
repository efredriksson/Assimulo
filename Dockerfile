FROM ubuntu:24.04

# ------------------------------------------------------------
# System tooling and Python
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    git \
    curl \
    liblapack-dev \
    cmake \
    build-essential \
    gfortran \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN cp -v /usr/lib/x86_64-linux-gnu/libblas.so \
          /usr/lib/x86_64-linux-gnu/libblas_OPENMP.so

# ------------------------------------------------------------
# SuperLU
# ------------------------------------------------------------
WORKDIR /tmp
RUN curl -fSsL https://github.com/xiaoyeli/superlu_mt/archive/refs/tags/v4.0.1.tar.gz \
    | tar xz

RUN cmake -S /tmp/superlu_mt-4.0.1 -B /tmp/superlu_mt-4.0.1/build \
    -Denable_examples=OFF \
    -Denable_tests=OFF \
    -DPLAT="_OPENMP" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DSUPERLUMT_INSTALL_INCLUDEDIR=include \
    && make -C /tmp/superlu_mt-4.0.1/build -j$(nproc) \
    && make -C /tmp/superlu_mt-4.0.1/build install \
    && rm -rf /tmp/superlu_mt-4.0.1

# ------------------------------------------------------------
# SUNDIALS
# ------------------------------------------------------------
ARG SUNDIALS_VERSION=7.1.1

RUN git clone --depth 1 -b v${SUNDIALS_VERSION} https://github.com/LLNL/sundials /tmp/sundials

# Patch for SUNDIALS 2.7.0
RUN if [ "${SUNDIALS_VERSION}" = "2.7.0" ]; then \
      echo "target_link_libraries(sundials_idas_shared lapack blas superlu_mt_OPENMP)" \
        >> /tmp/sundials/src/idas/CMakeLists.txt && \
      echo "target_link_libraries(sundials_kinsol_shared lapack blas superlu_mt_OPENMP)" \
        >> /tmp/sundials/src/kinsol/CMakeLists.txt ; \
    fi

RUN cmake -S /tmp/sundials -B /tmp/sundials/build \
    -LAH \
    -DSUPERLUMT_BLAS_LIBRARIES=blas \
    -DSUPERLUMT_LIBRARIES=blas \
    -DSUPERLUMT_INCLUDE_DIR=/usr/include \
    -DSUPERLUMT_LIBRARY=/usr/lib/libsuperlu_mt_OPENMP.a \
    -DSUPERLUMT_THREAD_TYPE=OpenMP \
    -DSUPERLUMT_ENABLE=ON \
    -DLAPACK_ENABLE=ON \
    -DEXAMPLES_ENABLE=OFF \
    -DEXAMPLES_ENABLE_C=OFF \
    -DBUILD_STATIC_LIBS=ON \
    -DSUNDIALS_INDEX_SIZE=32 \
    -DCMAKE_INSTALL_PREFIX=/usr \
    && make -C /tmp/sundials/build -j$(nproc) \
    && make -C /tmp/sundials/build install \
    && rm -rf /tmp/sundials

# ------------------------------------------------------------
# Final image state
# ------------------------------------------------------------
WORKDIR /src
CMD ["/bin/bash"]
