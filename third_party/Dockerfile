FROM debian:bookworm AS build

ARG BUSYBOX_VERSION=1.36.1
ARG BUSYBOX_SHA256=b8cc24c9574d809e7279c3be349795c5d5ceb6fdf19ca709f80cde50e47de314
ARG WPA_VERSION=2.10
ARG WPA_SHA256=20df7ae5154b3830355f8ab4269123a87affdea59fe74fe9292a91d0d7e17b2f

RUN sed -i 's|http://deb.debian.org|https://deb.debian.org|g' \
        /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources 2>/dev/null || true; \
    dpkg --add-architecture armel && \
    apt-get -o Acquire::Retries=5 -o Acquire::https::Timeout=30 update && \
    apt-get -o Acquire::Retries=5 -o Acquire::https::Timeout=30 \
        install -y --no-install-recommends \
        bzip2 ca-certificates curl file gcc gcc-arm-linux-gnueabi libc6-dev \
        libc6-dev-armel-cross \
        libnl-3-dev:armel libnl-genl-3-dev:armel make pkg-config && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN curl -fL --retry 5 --retry-all-errors --connect-timeout 20 \
        -o "busybox-${BUSYBOX_VERSION}.tar.bz2" \
        "https://sources.buildroot.net/busybox/busybox-${BUSYBOX_VERSION}.tar.bz2" && \
    echo "${BUSYBOX_SHA256}  busybox-${BUSYBOX_VERSION}.tar.bz2" | sha256sum -c - && \
    tar -xjf "busybox-${BUSYBOX_VERSION}.tar.bz2"

WORKDIR /build/busybox-${BUSYBOX_VERSION}
RUN make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig && \
    sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- -j"$(nproc)" && \
    mkdir -p /artifacts/bin /artifacts/licenses && \
    cp busybox /artifacts/bin/busybox-repeater && \
    cp LICENSE /artifacts/licenses/BusyBox-GPL-2.0.txt

WORKDIR /build
RUN curl -fL --retry 5 --retry-all-errors --connect-timeout 20 \
        -o "wpa_supplicant-${WPA_VERSION}.tar.gz" \
        "https://w1.fi/releases/wpa_supplicant-${WPA_VERSION}.tar.gz" && \
    echo "${WPA_SHA256}  wpa_supplicant-${WPA_VERSION}.tar.gz" | sha256sum -c - && \
    tar -xzf "wpa_supplicant-${WPA_VERSION}.tar.gz"

COPY third_party/wpa_supplicant.config /build/wpa_supplicant-${WPA_VERSION}/wpa_supplicant/.config
WORKDIR /build/wpa_supplicant-${WPA_VERSION}/wpa_supplicant
RUN PKG_CONFIG_LIBDIR=/usr/lib/arm-linux-gnueabi/pkgconfig \
    PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabi/pkgconfig \
    make CC=arm-linux-gnueabi-gcc -j"$(nproc)" wpa_supplicant wpa_cli && \
    cp wpa_supplicant /artifacts/bin/wpa_supplicant.hg5r && \
    cp wpa_cli /artifacts/bin/wpa_cli && \
    cp ../README /artifacts/licenses/wpa_supplicant-BSD-3-Clause.txt && \
    arm-linux-gnueabi-strip /artifacts/bin/*

FROM debian:bookworm-slim
COPY --from=build /artifacts /artifacts
CMD ["sh", "-c", "cp -a /artifacts/. /out/"]
