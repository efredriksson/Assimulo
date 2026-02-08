FROM ubuntu:latest

# ------------------------------------------------------------
# Python system level tooling
# ------------------------------------------------------------
RUN apt update && apt install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-setuptools \
    python3-wheel && \
    python3 -m pip install --break-system-packages pip-tools

# ------------------------------------------------------------
# System tooling
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    git \
    curl \
    liblapack-dev \
    libsuitesparse-dev \
    libhypre-dev \
    cmake \
    build-essential \
    gfortran \
    pkg-config \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*
RUN cp -v /usr/lib/x86_64-linux-gnu/libblas.so \
          /usr/lib/x86_64-linux-gnu/libblas_OPENMP.so

# ------------------------------------------------------------
# SuperLU
# ------------------------------------------------------------
WORKDIR /tmp
RUN curl -fSsL https://github.com/xiaoyeli/superlu_mt/archive/refs/tags/v4.0.1.tar.gz \
    | tar xz

WORKDIR /tmp/superlu_mt-4.0.1
RUN cmake \
    -Denable_examples=OFF \
    -Denable_tests=OFF \
    -DPLAT="_OPENMP" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DSUPERLUMT_INSTALL_INCLUDEDIR=include \
    . && \
    make -j4 && \
    make install

# ------------------------------------------------------------
# SUNDIALS
# ------------------------------------------------------------
ARG SUNDIALS_VERSION=7.1.1

WORKDIR /tmp
RUN git clone --depth 1 -b v${SUNDIALS_VERSION} https://github.com/LLNL/sundials sundials

WORKDIR /tmp/sundials
# Patch for SUNDIALS 2.7.0
RUN if [ "${SUNDIALS_VERSION}" = "2.7.0" ]; then \
      echo "target_link_libraries(sundials_idas_shared lapack blas superlu_mt_OPENMP)" \
        >> src/idas/CMakeLists.txt && \
      echo "target_link_libraries(sundials_kinsol_shared lapack blas superlu_mt_OPENMP)" \
        >> src/kinsol/CMakeLists.txt ; \
    fi

RUN mkdir build
WORKDIR /tmp/sundials/build

RUN cmake \
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
    .. && \
    make -j4 && \
    make install

# ------------------------------------------------------------
# Final image state
# ------------------------------------------------------------
WORKDIR /src
CMD ["/bin/bash"]
