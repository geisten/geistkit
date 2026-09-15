# Toolchain of the geisten CI (ubuntu-24.04, gcc-14, clang-19), base frozen by digest.
FROM ubuntu:24.04@sha256:224a1869083a311ef3f13648a154ba79832fbef6364d31493642ca03082da254

# ponytail: apt versions are logged (/toolchain.txt), not pinned.
# Upgrade path when bit-for-bit reproducibility matters: apt-get update --snapshot (snapshot.ubuntu.com).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gcc-14 g++-14 libc6-dev clang-19 libclang-rt-19-dev make git ca-certificates pkg-config \
      python3 python3-numpy libopenblas-dev libomp-dev libfftw3-dev \
 && ln -s /usr/bin/gcc-14 /usr/local/bin/gcc \
 && ln -s /usr/bin/gcc-14 /usr/local/bin/cc \
 && ln -s /usr/bin/g++-14 /usr/local/bin/g++ \
 && ln -s /usr/bin/g++-14 /usr/local/bin/c++ \
 && ln -s /usr/bin/clang-19 /usr/local/bin/clang \
 && dpkg-query -W -f '${Package} ${Version}\n' >/toolchain.txt \
 && rm -rf /var/lib/apt/lists/*
