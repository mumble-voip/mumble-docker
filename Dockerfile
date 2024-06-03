FROM ubuntu:22.04 as base

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
	libcap2 \
	libzeroc-ice3.7 \
	'^libprotobuf[0-9]+$' \
	libavahi-compat-libdnssd1 \
	libqt5core5a \
	libqt5network5 \
	libqt5sql5 \
	libqt5sql5-mysql \
	libqt5sql5-psql \
	libqt5sql5-sqlite \
	libqt5xml5 \
	libqt5dbus5 \
	ca-certificates \
	# Workaround for systems like CentOS 7 which won't load libQt5Core.so as expected:
	# see also https://stackoverflow.com/a/68897099/
	binutils \
	&& find /lib* /usr/lib* -name 'libQt5Core.so.*' -exec strip --remove-section=.note.ABI-tag {} \; \
	&& apt-get -y purge binutils \
	# End of workaround
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*



FROM base as build
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install --no-install-recommends -y \
  git cmake build-essential ca-certificates pkg-config \
  libssl-dev \
  qtbase5-dev \
  qttools5-dev \
  qttools5-dev-tools \
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
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ADD ./scripts/* /mumble/scripts/
WORKDIR /mumble/repo

ARG MUMBLE_VERSION=latest
ARG MUMBLE_BUILD_NUMBER=""
ARG MUMBLE_CMAKE_ARGS=""

# Clone the repo, build it and finally copy the default server ini file. Since this file may be at different locations and Docker
# doesn't support conditional copies, we have to ensure that regardless of where the file is located in the repo, it will end
# up at a unique path in our build container to be copied further down.
RUN /mumble/scripts/clone.sh && /mumble/scripts/build.sh \
&& /mumble/scripts/copy_one_of.sh ./scripts/murmur.ini ./auxiliary_files/mumble-server.ini default_config.ini



FROM base
ARG MUMBLE_UID=10000
ARG MUMBLE_GID=10000

RUN groupadd --gid $MUMBLE_GID mumble && useradd --uid $MUMBLE_UID --gid $MUMBLE_GID mumble

COPY --from=build /mumble/repo/build/mumble-server /usr/bin/mumble-server
COPY --from=build /mumble/repo/default_config.ini /etc/mumble/bare_config.ini

RUN mkdir -p /data && chown -R mumble:mumble /data && chown -R mumble:mumble /etc/mumble
EXPOSE 64738/tcp 64738/udp
COPY entrypoint.sh /entrypoint.sh

VOLUME ["/data"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/mumble-server", "-fg"]

