**Mumble** is a VOIP application which allows users to talk to each other via
the same server. It uses a client-server architecture, and encrypts all
communication to ensure user privacy. **Murmur** is the name of the server
component within the Mumble project.[Learn More][mumble-wiki].

`mumble-voip/mumble-server` enables you to easily run multiple (lightweight) murmur
instances on the same host.

## Getting started

This guide assumes that you already have [Docker][docker-install-docs]
installed.

### Pull the official image

An image is available from the [Docker Hub][docker-hub-repo-url] registry, built
automatically from this repository. It's easy to get started:

```text
docker pull mumble-voip/mumble-server[:tag]
```

You don't _need_ to specify a tag, but it's a good idea to so that you don't
pull `latest` and risk getting different versions on different hosts. Versions
are kept in line with the [releases from mumble-voip/mumble][vendor-releases].

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
    mumble-voip/mumble-server[:tag]
```

You should now be able to open up the Mumble client, and connect to the server
running at `127.0.0.1:64738`.

### Configuration options

The following variables can be passed into the container (when you execute
`docker run`) to change various configuration options.

For example:

```text
docker run -d \
    -p 64738:64738/tcp \
    -p 64738:64738/udp
    -e MUMBLE_SERVERPASSWORD='superSecretPasswordHere' \
    --name mumble-server-001 \
    mumble-voip/mumble-server[:tag]
```

Here is a list of all options supported through environment variables:

| Environment Variable | Default Value |
| -------------------- | ------------- |
| [`MUMBLE_ALLOWHTML`][mdoc-allowhtml] | `true`|
| [`MUMBLE_ALLOWPING`][mdoc-allowping] | `true`|
| [`MUMBLE_AUTOBANATTEMPTS`][mdoc-group-autoban] | `10`    |
| [`MUMBLE_AUTOBANTIMEFRAME`][mdoc-group-autoban] | `120` |
| [`MUMBLE_AUTOBANTIME`][mdoc-group-autoban] | `300` |
| [`MUMBLE_BANDWIDTH`][mdoc-bandwidth] | `7200`|
| [`MUMBLE_CHANNELNAME`][mdoc-group-channelusername] | `[ \\-=\\w\\#\\[\\]\\{\\}\\(\\)\\@\\|]+` |
| [`MUMBLE_DATABASE`][mdoc-group-database] | `/data/murmur.sqlite` |
| [`MUMBLE_DB_DRIVER`][mdoc-group-database] | `QSQLITE` |
| [`MUMBLE_DB_USERNAME`][mdoc-group-database] | `---` |
| [`MUMBLE_DB_PASSWORD`][mdoc-group-database] | `---` |
| [`MUMBLE_DEFAULTCHANNEL`][mdoc-defaultchannel] | `---` |
| [`MUMBLE_ENABLESSL`](#ssl-certificates-murmurinissl) | `0` |
| [`MUMBLE_ICE`][mdoc-ice] | `tcp -h 127.0.0.1 -p 6502` |
| [`MUMBLE_ICESECRETREAD`][mdoc-group-icesecret] | `---` |
| [`MUMBLE_ICESECRETWRITE`][mdoc-group-icesecret] | `---` |
| [`MUMBLE_IMAGEMESSAGELENGTH`][mdoc-imagemessagelength] |`131072` |
| [`MUMBLE_KDFITERATIONS`][mdoc-kdfIterations] | `-1`|
| [`MUMBLE_LEGACYPASSWORDHASH`][mdoc-legacyPasswordHash] | `false` |
| [`MUMBLE_MESSAGEBURST`][mdoc-ratelimit] | `5` |
| [`MUMBLE_MESSAGELIMIT`][mdoc-ratelimit] | `1` |
| [`MUMBLE_OBFUSCATE`][mdoc-obfuscate] | `false` |
| [`MUMBLE_OPUSTHRESHOLD`][mdoc-opusthreshold] | `100` |
| [`MUMBLE_REGISTERHOSTNAME`][mdoc-registerHostname] | `---` |
| [`MUMBLE_REGISTERNAME`][mdoc-registerName] | `---`|
| [`MUMBLE_REGISTERPASSWORD`][mdoc-registerPassword] | `---` |
| [`MUMBLE_REGISTERURL`][mdoc-registerUrl] | `---` |
| [`MUMBLE_REMEMBERCHANNEL`][mdoc-rememberchannel] | `true`|
| [`MUMBLE_SENDVERSION`][mdoc-sendversion] | `false`|
| [`MUMBLE_SERVERPASSWORD`][mdoc-serverpassword] | `---` |
| [`MUMBLE_SSLCIPHERS`](#ssl-certificates-murmurinissl) | `---` |
| [`MUMBLE_SSLPASSPHRASE`](#ssl-certificates-murmurinissl) | `---` |
| [`MUMBLE_SUGGESTPOSITIONAL`][mdoc-suggestPositional] | `---` |
| [`MUMBLE_SUGGESTPUSHTOTALK`][mdoc-suggestPushToTalk] | `---` |
| [`MUMBLE_SUGGESTVERSION`][mdoc-suggestVersion] | `false` |
| [`MUMBLE_TEXTMESSAGELENGTH`][mdoc-textmessagelength] | `5000`|
| [`MUMBLE_TIMEOUT`][mdoc-timeout] | `30`|
| [`MUMBLE_USERNAME`][mdoc-group-channelusername] | `[-=\\w\\[\\]\\{\\}\\(\\)\\@\\|\\.]+` |
| [`MUMBLE_USERS`][mdoc-users] | `100` |
| [`MUMBLE_USERSPERCHANNEL`][mdoc-usersperchannel] | `0` |
| [`MUMBLE_WELCOMETEXT`][mdoc-welcometext] | `<br />Welcome...` |
| `SUPERUSER_PASSWORD` | If not defined, a password will be auto-generated. |

### Custom welcome text ([Murmur.ini::welcometext][mdoc-welcometext])

If the environnement variable `MUMBLE_WELCOMETEXT` will produce to big config for you, 
you can customize the welcome text with a separate file.
Add the contents to `welcometext` and mount that
into the container at `/data/welcometext`. Double quote characters (`"`) are
escaped automatically, but you may want to confirm that your message was parsed
correctly.

### Custom configuration file
If you want to use a fully set murmur configuration file, 
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


### Numbered tags

For a full list of tags, please see the [tags page][tags] on Docker Hub.

Numbered tags follow the pattern:

```
<MUMBLE_VERSION>-<RELEASE>
  │                └─ the release number specific to this repository
  │
  └──── the version of mumble for this release
```