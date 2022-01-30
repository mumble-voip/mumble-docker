**Mumble** is a VOIP application which allows users to talk to each other via
the same server. It uses a client-server architecture, and encrypts all
communication to ensure user privacy. **Mumble-server** is the name of the server
component within the Mumble project.

`mumble-voip/mumble-server` enables you to easily run multiple (lightweight) mumble-server
instances on the same host.

## Getting started

This guide assumes that you already have installed.

### Pull the official image
#### NOT READY
An image is available from the [Docker Hub](https://hub.docker.com/r/mumblevoip/mumble-server) registry, built
automatically from this repository. It's easy to get started:

```text
docker pull mumble-voip/mumble-server[:tag]
```

You don't _need_ to specify a tag, but it's a good idea to so that you don't
pull `latest` and risk getting different versions on different hosts. Versions
are kept in line with the [releases from mumble-voip/mumble-docker](https://github.com/mumble-voip/mumble-docker/tags).

The examples throughout this document assume we are not using a tag for the sake
of brevity. If you pull the image with a tag other than `latest`, you will need
to use that tag number when running the image via `docker run`.

### Create a container

Now that you have the image pulled, it's time to get a container up and running.

```text
docker run -d \
    -p 64738:64738/tcp \
    -p 64738:64738/udp \
    --name mumble-server-001 \
    -v ./data/mumble-server/database.sqlite:/data/database.sqlite \
    mumble-voip/mumble-server[:tag]
```

You should now be able to open up the Mumble client, and connect to the server
running at `127.0.0.1:64738`.
Please note I use a volume to backup the sqlite database on my disk with a relative path.

### Configuration options

The following variables can be passed into the container (when you execute
`docker run`) to change various configuration options.

For example:

```text
docker run -d \
    -p 64738:64738/tcp \
    -p 64738:64738/udp \
    -e MUMBLE_SERVERPASSWORD='superSecretPasswordHere' \
    -v ./data/mumble-server/database.sqlite:/data/database.sqlite
    --name mumble-server-001 \
    mumble-voip/mumble-server[:tag]
```

All variables are similar to the [official ini file](https://github.com/mumble-voip/mumble/blob/master/scripts/murmur.ini) without the prefix `MUMBLE_`.
Here is a list of all options supported through environment variables:

| Environment Variable | Default Value |
| -------------------- | ------------- |
| `MUMBLE_ALLOWHTML` | `true`|
| `MUMBLE_ALLOWPING` | `true`|
| `MUMBLE_AUTOBANATTEMPTS` | `10`    |
| `MUMBLE_AUTOBANTIMEFRAME` | `120` |
| `MUMBLE_AUTOBANTIME` | `300` |
| `MUMBLE_BANDWIDTH` | `7200`|
| `MUMBLE_CHANNELNAME` | `[ \\-=\\w\\#\\[\\]\\{\\}\\(\\)\\@\\|]+` |
| `MUMBLE_DATABASE` | `/data/murmur.sqlite` |
| `MUMBLE_DB_DRIVER` | `QSQLITE` |
| `MUMBLE_DB_USERNAME` | `---` |
| `MUMBLE_DB_PASSWORD` | `---` |
| `MUMBLE_DEFAULTCHANNEL` | `---` |
| `MUMBLE_ENABLESSL` | `0` |
| `MUMBLE_ICE` | `tcp -h 127.0.0.1 -p 6502` |
| `MUMBLE_ICESECRETREAD` | `---` |
| `MUMBLE_ICESECRETWRITE` | `---` |
| `MUMBLE_IMAGEMESSAGELENGTH` |`131072` |
| `MUMBLE_KDFITERATIONS` | `-1`|
| `MUMBLE_LEGACYPASSWORDHASH` | `false` |
| `MUMBLE_MESSAGEBURST` | `5` |
| `MUMBLE_MESSAGELIMIT` | `1` |
| `MUMBLE_OBFUSCATE` | `false` |
| `MUMBLE_OPUSTHRESHOLD` | `100` |
| `MUMBLE_REGISTERHOSTNAME` | `---` |
| `MUMBLE_REGISTERNAME` | `---`|
| `MUMBLE_REGISTERPASSWORD` | `---` |
| `MUMBLE_REGISTERURL` | `---` |
| `MUMBLE_REMEMBERCHANNEL` | `true`|
| `MUMBLE_SENDVERSION` | `false`|
| `MUMBLE_SERVERPASSWORD` | `---` |
| `MUMBLE_SSLCIPHERS` | `---` |
| `MUMBLE_SSLPASSPHRASE` | `---` |
| `MUMBLE_SUGGESTPOSITIONAL` | `---` |
| `MUMBLE_SUGGESTPUSHTOTALK` | `---` |
| `MUMBLE_SUGGESTVERSION` | `false` |
| `MUMBLE_TEXTMESSAGELENGTH` | `5000`|
| `MUMBLE_TIMEOUT` | `30`|
| `MUMBLE_USERNAME` | `[-=\\w\\[\\]\\{\\}\\(\\)\\@\\|\\.]+` |
| `MUMBLE_USERS` | `100` |
| `MUMBLE_USERSPERCHANNEL` | `0` |
| `MUMBLE_WELCOMETEXT` | `<br />Welcome...` |
| `SUPERUSER_PASSWORD` | If not defined, a password will be auto-generated. |

### Custom welcome text ([Murmur.ini::welcometext][mdoc-welcometext])

If the environnement variable `MUMBLE_WELCOMETEXT` will produce to big config for you, 
you can customize the welcome text with a separate file.
Add the contents to `welcometext` file and mount this file 
into the container at `/data/welcometext`. Double quote characters (`"`) are
escaped automatically, but you may want to confirm that your message was parsed
correctly.

### Custom configuration file
If you want to use a fully set mumble-server configuration file, 
you can mount the file into the container at `/data/murmur.ini`
You cannot have both environment variables AND config file. The config file override everything.

### SSL Certificates ([Murmur.ini::SSL][mdoc-sslcertkey])

The server will generate its own SSL certificates when the daemon is started. If
you wish to provide your own certificates and ciphers instead, you can do so by
following the instructions below.

If `MUMBLE_ENABLESSL` is set to `1`, custom SSL is enabled, as long as you have
mounted a certificate and key at the following locations:

- SSL certificate should be mounted at `/data/cert.pem`

  - If your certificate is signed by an authority that uses a sub-signed or
    "intermediate" certificate, you should either bundle that with your
    certificate, or mount it in separately at `/data/intermediate.pem` - this
    will be automatically detected.

- SSL key should be mounted at `/data/key.pem`

  - If the key has a passphrase, you should define the environment variable
    `MUMBLE_SSLPASSPHRASE` with the passphrase. This variable does not have any
    effect if you have not mounted a key *and* enabled SSL.

- Set your preferred cipher suite using `MUMBLE_SSLCIPHERS`

  - This option chooses the cipher suites to make available for use in SSL/TLS.
    See the [official documentation][mdoc-sslCiphers] for more information.

### Logging in as SuperUser

If the environment variable `SUPERUSER_PASSWORD` is not defined when creating
the container, a password will be automatically generated. To view the password
for any container at any time, look at the container's logs. As an example, to
view the SuperUser password is for an instance running in a container named
`mumble-server-001`:

```text
$ docker logs mumble-server-001 2>&1 | grep SUPERUSER_PASSWORD
> SUPERUSER_PASSWORD: <value>
```

### Local build
If you want to build the image yourself, you need to add the MUMBLE_VERSION arg.
Command :
```
docker build --build-arg MUMBLE_VERSION=v1.4.230 mumble-docker/
```
