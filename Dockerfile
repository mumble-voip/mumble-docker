FROM ubuntu:24.04 AS base

ADD ./scripts/* /mumble/scripts/
WORKDIR /mumble/scripts

ARG DEBIAN_FRONTEND=noninteractive
ARG MUMBLE_VERSION=latest

RUN apt-get update && apt-get install --no-install-recommends -y \
    libcap2 \
    libzeroc-ice3.7t64 \
    '^libprotobuf[0-9]+$' \
    libavahi-compat-libdnssd1 \
    ca-certificates \
    && export QT_VERSION="$( /mumble/scripts/choose_qt_version.sh )" \
    && /mumble/scripts/install_qt.sh \
    # Workaround for systems like CentOS 7 which won't load libQt5Core.so as expected:
    # see also https://stackoverflow.com/a/68897099/
    binutils \
    && find /lib* /usr/lib* -name 'libQt?Core.so.*' -exec strip --remove-section=.note.ABI-tag {} \; \
    && apt-get -y purge binutils \
    # End of workaround
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /data \
    && rm -Rf /scripts



FROM base AS build
ARG DEBIAN_FRONTEND=noninteractive

ADD ./scripts/* /mumble/scripts/
WORKDIR /mumble/repo

RUN apt-get update && apt-get install --no-install-recommends -y \
    git cmake build-essential ca-certificates pkg-config \
    libssl-dev \
    libboost-dev \
    libprotobuf-dev \
    protobuf-compiler \
    libprotoc-dev \
    libcap-dev \
    libxi-dev \
    libavahi-compat-libdnssd-dev \
    libzeroc-ice-dev \
    python3 \
    git \
    && export QT_VERSION="$( /mumble/scripts/choose_qt_version.sh )" \
    && /mumble/scripts/install_qt_dev.sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ARG MUMBLE_VERSION=latest
ARG MUMBLE_BUILD_NUMBER=""
ARG MUMBLE_CMAKE_ARGS=""

# Clone the repo, build it and finally copy the default server ini file. Since this file may be at different locations and Docker
# doesn't support conditional copies, we have to ensure that regardless of where the file is located in the repo, it will end
# up at a unique path in our build container to be copied further down.
RUN /mumble/scripts/clone.sh \
    && /mumble/scripts/build.sh \
    && /mumble/scripts/copy_one_of.sh ./scripts/murmur.ini ./auxiliary_files/mumble-server.ini default_config.ini

RUN git clone https://github.com/ncopa/su-exec.git /mumble/repo/su-exec \
    && cd /mumble/repo/su-exec && make



FROM base

COPY --from=build /mumble/repo/build/mumble-server /usr/bin/mumble-server
COPY --from=build /mumble/repo/default_config.ini /etc/mumble/bare_config.ini
COPY --from=build --chmod=755 /mumble/repo/su-exec/su-exec /usr/local/bin/su-exec


EXPOSE 64738/tcp 64738/udp
COPY entrypoint.sh /entrypoint.sh

VOLUME ["/data"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/mumble-server", "-fg"]

