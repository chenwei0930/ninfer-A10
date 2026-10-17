# syntax=docker/dockerfile:1

FROM nvidia/cuda:13.1.2-devel-ubuntu24.04 AS build

ARG DEBIAN_FRONTEND=noninteractive
ARG UPSTREAM_REF=unknown

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        cmake \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libcurl4-openssl-dev \
        libswscale-dev \
        ninja-build \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

RUN cmake -S . -B /build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DNINFER_BUILD_APPS=ON \
        -DBUILD_TESTING=OFF \
        -DNINFER_BUILD_BENCHMARKS=OFF \
    && cmake --build /build --parallel --target ninfer ninfer-serve


FROM nvidia/cuda:13.1.2-runtime-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UPSTREAM_REF=unknown

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        libavcodec60 \
        libavformat60 \
        libavutil58 \
        libcurl4t64 \
        libswscale7 \
    && rm -rf /var/lib/apt/lists/*

# 跟随上游 Dockerfile：移除 CUDA forward-compatibility 库，
# 让容器使用宿主机提供的 NVIDIA 驱动库。
RUN rm -rf \
    /usr/local/cuda-13.1/compat \
    /usr/local/cuda-13/compat \
    /usr/local/cuda/compat

COPY --from=build /build/apps/ninfer /usr/local/bin/ninfer
COPY --from=build /build/apps/ninfer-serve /usr/local/bin/ninfer-serve

LABEL org.opencontainers.image.source="https://github.com/Don-Chad/ninfer-3090" \
      org.opencontainers.image.revision="${UPSTREAM_REF}"

WORKDIR /workspace
EXPOSE 8080
STOPSIGNAL SIGTERM

CMD ["ninfer-serve", "--help"]
