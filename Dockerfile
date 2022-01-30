# https://github.com/mumble-voip/mumble/blob/master/docs/dev/build-instructions/build_linux.md

FROM ubuntu:21.10 as base

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
	libcap2 \
	libzeroc-ice3.7 \
	'^libprotobuf[0-9]+$' \
	'^libgrpc[0-9]+$' \
	libgrpc++1 \
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
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

FROM base as build
ARG DEBIAN_FRONTEND=noninteractive
ARG MUMBLE_VERSION=v1.4.230

RUN apt-get update && apt-get install --no-install-recommends -y \
  git cmake build-essential ca-certificates pkg-config \
  libssl-dev \
  qtbase5-dev \
  qttools5-dev \
  qttools5-dev-tools \
  libqt5svg5-dev \
  libboost-dev \
  libssl-dev \
  libprotobuf-dev \
  protobuf-compiler \
  libprotoc-dev \
  libcap-dev \
  libxi-dev \
  libasound2-dev \
  libogg-dev \
  libsndfile1-dev \
  libspeechd-dev \
  libavahi-compat-libdnssd-dev \
  libzeroc-ice-dev \
  libpoco-dev \
  libgrpc++-dev \
  protobuf-compiler-grpc \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
    
RUN git clone https://github.com/mumble-voip/mumble/
WORKDIR /mumble/build
RUN git checkout "$MUMBLE_VERSION" && git submodule update --init --recursive

RUN cmake -Dclient=OFF -DCMAKE_BUILD_TYPE=Release .. && cmake --build . -j $(nproc)

FROM base
RUN adduser murmur

COPY --from=build /mumble/build/mumble-server /usr/bin/mumble-server

# Copy project files into container
COPY ./config /etc/murmur
COPY ./docker-entrypoint.sh /

RUN chown -R murmur:nogroup /etc/murmur/

EXPOSE 64738/tcp 64738/udp 50051
USER murmur

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["/usr/bin/mumble-server", "-fg"]
