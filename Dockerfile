# ------------------------------------------------------#
# --- Build stage for the entrypoint.sh replacement ----#
# ------------------------------------------------------#
FROM rust:slim-bookworm as builder
WORKDIR /data
COPY Cargo.toml /data
COPY Cargo.lock /data
RUN mkdir -p /data/src
RUN echo 'fn main() {}' > /data/src/main.rs
RUN cargo build
COPY ./src/main.rs /data/src/main.rs
RUN cargo build --release

# ------------------------------------------------------#
# --- Runtime image with mumble-server's dependencies --#
# --- (Used to extract the shared libs from later) -----#
# ------------------------------------------------------#
FROM debian:bookworm-slim as base

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



# ------------------------------------------------------#
# --- Build stage for mumble-server itself -------------#
# ------------------------------------------------------#
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


# ------------------------------------------------------#
# --- Preparation stage that could run mumble ----------#
# --- Determines config files and libs for final stage -#
# ------------------------------------------------------#
FROM base as runner
ARG MUMBLE_UID=1000
ARG MUMBLE_GID=1000

RUN groupadd --gid $MUMBLE_GID mumble && useradd --uid $MUMBLE_UID --gid $MUMBLE_GID mumble

COPY --from=build /mumble/repo/build/mumble-server /usr/bin/mumble-server
COPY --from=build /mumble/repo/default_config.ini /etc/mumble/bare_config.ini

RUN mkdir -p /data && chown -R mumble:mumble /data && chown -R mumble:mumble /etc/mumble

COPY copy-libs.sh /copy-libs.sh
COPY entrypoint.sh /entrypoint.sh
COPY --from=builder /data/target/release/mumble-docker/ /mumble-docker-entrypoint

# Copy over all required shared libraries to /lib/copy so we can
# reuse them in the distroless container in the final stage
RUN /copy-libs.sh /mumble-docker-entrypoint /lib/copy
RUN /copy-libs.sh /usr/bin/mumble-server /lib/copy
RUN /copy-libs.sh /lib/x86_64-linux-gnu/qt5/plugins/sqldrivers/libqsqlite.so /lib/copy
RUN cp -r /lib/x86_64-linux-gnu/qt-default /lib/copy
RUN cp -r /lib/x86_64-linux-gnu/qt5/ /lib/copy

# ------------------------------------------------------#
# --- Distroless base image for the final container --- #
# --- Copying over needed libs from previous stage ---- #
# ------------------------------------------------------#
FROM gcr.io/distroless/cc-debian12:latest
COPY --from=runner /etc/passwd /etc/passwd
COPY --from=runner /etc/shadow /etc/shadow
COPY --from=runner /usr/bin/mumble-server /usr/bin/mumble-server
COPY --from=runner /lib/copy /usr/lib/x86_64-linux-gnu
COPY --from=runner /etc/mumble /etc/mumble
COPY --chown=1000:1000 --from=runner /data /data
COPY --from=runner /mumble-docker-entrypoint /mumble-docker-entrypoint

USER mumble
EXPOSE 64738/tcp 64738/udp
VOLUME ["/data"]
ENTRYPOINT ["/mumble-docker-entrypoint"]
CMD ["/usr/bin/mumble-server", "-fg"]

