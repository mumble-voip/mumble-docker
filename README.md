# Mumble Docker

Mumble is a free, open source, low latency, high quality voice chat application.

<p align="center"><b><a href="https://mumble.info">Mumble Website</a> • <a href="https://github.com/mumble-voip/mumble">Mumble Source</a></b></p>

This is the official code of the Mumble Docker image for self-hosting the **Mumble server**. The image is available for download on
**[Dockerhub](https://hub.docker.com/r/mumblevoip/mumble-server)**.

-----

## Quick Start Guide

1. [Running the container](#running-the-container)
2. [Configuration](#configuration)
3. [Building the container](#Building-the-container)


## Running the container

### Requirements

This documentation assumes that you already have Docker installed and configured on your target machine. You may find it more convenient to set up the
Docker container using [docker-compose](https://docs.docker.com/compose/). Thus, we also provide instructions for that scenario (see below).

In order for Mumble to store permanent data (most notably the database file (by default Mumble uses SQLite)), the image will use a
[volume](https://docs.docker.com/storage/volumes/) which is mapped to the `/data/` path inside the image. By default the image uses a user with UID
`10000` and GID of also `10000` but either can be adapted when building the image yourself (see below). You will have to make sure that all file
permissions are set up accordingly.

### Running the container

**Using docker**:
```bash
$ docker run --detach \
             --name mumble-server \
             --publish 64738:64738/tcp \
             --publish 64738:64738/udp \
             --volume ./data/mumble:/data \
             --restart on-failure \
             mumblevoip/mumble-server:<tag>
```
For possible values of `<tag>` see below.

**Using docker-compose**:
```yaml
services:
    mumble-server:
        image: mumblevoip/mumble-server:<tag>
        container_name: mumble-server
        hostname: mumble-server
        restart: on-failure
        ports:
            - 64738:64738
            - 64738:64738/udp
#       expose:
#           - 6502
```
For possible values of `<tag>` see below.

The additional port `6502` could for instance be used to expose the [ICE interface](https://wiki.mumble.info/wiki/Murmur.ini#ice). You'll obviously
have to adapt the used port for whatever you configured in the server's configuration file.

### Tags

For an up-to-date list of available tags, see [Dockerhub](https://hub.docker.com/r/mumblevoip/mumble-server/tags). Generally, you can either use
`latest` to always fetch the latest version or tags of the form `vX.Y.Z` corresponding to the respective stable releases of Mumble, e.g. `v1.4.230`.


## Configuration

The preferred way of configuring the server instance in the Docker container is by means of environment variables. All of these variables take the
form `MUMBLE_CONFIG_<configName>`, where `<configName>` is the name of the configuration to set. All config options that can be set in the regular
Mumble server configuration file (historically called `murmur.ini`) can be set. For an overview of available options, see
[here](https://wiki.mumble.info/wiki/Murmur.ini).

`<configName>` is case-insensitive and underscores may be inserted into the respective config name, to increase readability. Thus,
`MUMBLE_CONFIG_dbhost`, `MUMBLE_CONFIG_DBHOST` and `MUMBLE_CONFIG_DB_HOST` all refer to the same config `dbHost`.

The container entrypoint will use these environment variables and build a corresponding configuration file from it on-the-fly, which is then used the
spun-up server.

You can specify these environment variables when starting the container using the `-e` command-line option as documented
[here](https://docs.docker.com/engine/reference/run/#env-environment-variables):
```bash
$ docker run -e "MUMBLE_CONFIG_SERVER_PASSWORD=123"
```

As an alternative to environment variables, docker or podman secrets can be used to read configuration options from files which follow the `MUMBLE_CONFIG_<config_name>` name pattern and are located in the `/run/secrets` directory at runtime. The same rules to naming environment variables apply to these files as well.

Please consult the documentation of docker or podman on how to use secrets for further details.
- [Docker (Swarm) Secrets](https://docs.docker.com/engine/swarm/secrets/)
- Podman Secrets
  - [podman run with secrets](https://docs.podman.io/en/latest/markdown/podman-run.1.html#secret-secret-opt-opt)
  - [podman secret subcommand](https://docs.podman.io/en/latest/markdown/podman-secret.1.html)

### Example: Running the container with secrets using podman
To set the server password and superuser password using podman secrets, the following series of commands can be used:

```bash
# Create the secrets
echo -n "secretserver" | podman secret create MUMBLE_CONFIG_SERVER_PASSWORD -
echo -n "supassword" | podman secret create MUMBLE_SUPERUSER_PASSWORD -

# Run the server with these secrets mounted
podman run --detach \
           --name mumble-server \
           --publish 64738:64738/tcp \
           --publish 64738:64738/udp \
           --secret MUMBLE_CONFIG_SERVER_PASSWORD \
           --secret MUMBLE_SUPERUSER_PASSWORD \
           --volume ./data/mumble:/data \
           --restart on-failure \
           mumblevoip/mumble-server:<tag>
```

### Additional variables

The following _additional_ variables can be set for further server configuration:

| Environment Variable             | Description                                                                                                                                  |
|----------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------- |
| `MUMBLE_ACCEPT_UNKNOWN_SETTINGS` | Set to `true` to force the container to accept unknown settings passed as a `MUMBLE_CONFIG_` variable (see note below).                      |
| `MUMBLE_CUSTOM_CONFIG_FILE`      | Specify a custom config file path - **all `MUMBLE_CONFIG_` variables are IGNORED** <br/>(it's best to use a path inside the volume `/data/`) |
| `MUMBLE_SUPERUSER_PASSWORD`      | Specifies the SuperUser (Admin) password for this server. If this is not given, a random password will be generated upon first startup.      |
| `MUMBLE_VERBOSE`                 | Set to `true` to enable verbose logging in the server                                                                                        |


Note: In the unlikely case where a `<configName>` setting is unknown to the container, startup will fail with the following error. 


```
mumble-server  | [ERROR]: Unable to find config corresponding to variable "<configName>"
mumble-server exited with code 1
```

The root cause of this error is the fact that this setting is incorrectly registered in the Mumble server code. You can workaround this error by 
setting the `MUMBLE_ACCEPT_UNKNOWN_SETTINGS` environment variable to `true` and spelling `<configName>` exactly as written in the
[Murmur.ini](https://wiki.mumble.info/wiki/Murmur.ini) documentation.


## Building the container

After having cloned this repository, you can just run
```bash
$ docker build .
```
in order to build a Mumble server from the latest commit in the upstream [master branch](https://github.com/mumble-voip/mumble/commits/master).

If you prefer to instead build a specific version of the Mumble server, you can use the `MUMBLE_VERSION` argument like this:
```bash
$ docker build --build-arg MUMBLE_VERSION=v1.4.230 .
```
`MUMBLE_VERSION` can either be one of the [published tags](https://github.com/mumble-voip/mumble/tags) of the upstream repository or a commit hash of
the respective commit to build.

Note that either way, only Mumble versions >= 1.4 can be built using this image. Mumble versions 1.3 and earlier are not compatible with the build
process employed by this Docker image.

### Using a different UID/GID

Additionally, it is possible to specify the UID and the GID of the `mumble` user that is used inside the container. These can be controlled by the
`MUMBLE_UID` and `MUMBLE_GID` build variables respectively. This is intended to allow you to use the same UID and GID as your user on your host
system, in order to cause minimal issues when accessing mounted volumes.

### Using custom build options

It is also possible to pass custom cmake options to the build process by means of the `MUMBLE_CMAKE_ARGS` build variable. That way, you can customize
the build to your liking. For instance, this could be used to enable the Tracy profiler (assuming you are building a version of the server that has
support for it):
```bash
$ docker build --build-arg MUMBLE_CMAKE_ARGS="-Dtracy=ON"
```

For an overview of all available build options, check the
[build instructions](https://github.com/mumble-voip/mumble/blob/master/docs/dev/build-instructions) of the main project.


### Common build issues

Should you see the error
```
Got permission denied while trying to connect to the Docker daemon socket
```
you most likely invoked `docker` as a non-root user. In order for that to be possible, you need to add yourself to the `docker` group on your system.
See the [official docs](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user) on this topic for further
information.

