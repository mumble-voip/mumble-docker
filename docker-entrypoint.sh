#!/usr/bin/env sh
set -e

CONFIGFILE="/etc/murmur/murmur.ini"
ICEFILE="/etc/murmur/ice.ini"
WELCOMEFILE="/data/welcometext"
CUSTOM_CONFIG_FILE="/data/murmur.ini"

setVal() {
    if [ -n "${1}" ] && [ -n "${2}" ]; then
        echo "update setting: ${1} with: ${2}"
        tmp=$(echo $2 | sed 's,\\,\\\\,g') # Double every \ for next sed
        sed -i -E 's#;?('"${1}"'=).*#\1'"${tmp}"'#' "${CONFIGFILE}"
    fi
}

setVal database "${MUMBLE_DATABASE}"
setVal dbDriver "${MUMBLE_DB_DRIVER}"
setVal dbUsername "${MUMBLE_DB_USERNAME}"
setVal dbPassword "${MUMBLE_DB_PASSWORD}"
setVal dbHost "${MUMBLE_DB_HOST}"
setVal ice "${MUMBLE_ICE}"
setVal icesecretread "${MUMBLE_ICESECRETREAD}"
setVal icesecretwrite "${MUMBLE_ICESECRETWRITE}"
setVal autobanAttempts "${MUMBLE_AUTOBANATTEMPTS}"
setVal autobanTimeframe "${MUMBLE_AUTOBANTIMEFRAME}"
setVal autobanTime "${MUMBLE_AUTOBANTIME}"
setVal serverpassword "${MUMBLE_SERVERPASSWORD}"
setVal obfuscate "${MUMBLE_OBFUSCATE}"
setVal sendversion "${MUMBLE_SENDVERSION}"
setVal legacyPasswordHash "${MUMBLE_LEGACYPASSWORDHASH}"
setVal kdfIterations "${MUMBLE_KDFITERATIONS}"
setVal allowping "${MUMBLE_ALLOWPING}"
setVal bandwidth "${MUMBLE_BANDWIDTH}"
setVal timeout "${MUMBLE_TIMEOUT}"
setVal certrequired "${MUMBLE_CERTREQUIRED}"
setVal users "${MUMBLE_USERS}"
setVal usersperchannel "${MUMBLE_USERSPERCHANNEL}"
setVal username "${MUMBLE_USERNAME}"
setVal channelname "${MUMBLE_CHANNELNAME}"
setVal channelnestinglimit "${MUMBLE_CHANNELNESTINGLIMIT}"
setVal defaultchannel "${MUMBLE_DEFAULTCHANNEL}"
setVal rememberchannel "${MUMBLE_REMEMBERCHANNEL}"
setVal textmessagelength "${MUMBLE_TEXTMESSAGELENGTH}"
setVal imagemessagelength "${MUMBLE_IMAGEMESSAGELENGTH}"
setVal allowhtml "${MUMBLE_ALLOWHTML}"
setVal opusthreshold "${MUMBLE_OPUSTHRESHOLD}"
setVal messagelimit "${MUMBLE_MESSAGELIMIT}"
setVal messageburst "${MUMBLE_MESSAGEBURST}"
setVal registerHostname "${MUMBLE_REGISTERHOSTNAME}"
setVal registerPassword "${MUMBLE_REGISTERPASSWORD}"
setVal registerUrl "${MUMBLE_REGISTERURL}"
setVal registerName "${MUMBLE_REGISTERNAME}"
setVal suggestVersion "${MUMBLE_SUGGESTVERSION}"
setVal suggestPositional "${MUMBLE_SUGGESTPOSITIONAL}"
setVal suggestPushToTalk "${MUMBLE_SUGGESTPUSHTOTALK}"
setVal welcometext "${MUMBLE_WELCOMETEXT}"


if [ -n "${MUMBLE_ENABLESSL}" ] && [ "${MUMBLE_ENABLESSL}" -eq 1 ]; then
    SSL_CERTFILE=${MUMBLE_CERTFILE:-/data/cert.pem}
    SSL_KEYFILE=${MUMBLE_KEYFILE:-/data/key.pem}
    SSL_CAFILE=${MUMBLE_CAFILE:-/data/intermediate.pem}
    SSL_DHFILE=${MUMBLE_DHFILE:-/data/dh.pem}

    if [ -f "${SSL_CERTFILE}" ]; then
        setVal sslCert "${SSL_CERTFILE}"
    fi

    if [ -f "${SSL_KEYFILE}" ]; then
        setVal sslKey "${SSL_KEYFILE}"
        setVal sslPassPhrase "${MUMBLE_SSLPASSPHRASE}"
    fi

    if [ -f "${SSL_CAFILE}" ]; then
        setVal sslCA "${SSL_CAFILE}"
    fi

    if [ -f "${SSL_DHFILE}" ]; then
        setVal sslDHParams "${SSL_DHFILE}"
    fi

    setVal sslCiphers "${MUMBLE_SSLCIPHERS}"
fi

if [ -f "${WELCOMEFILE}" ]; then
    parsedContent=$(sed -E 's/"/\\"/g' "${WELCOMEFILE}")
    setVal welcometext "\"$parsedContent\""
fi

if ! grep -q '\[Ice\]' "${CONFIGFILE}"; then
    echo "" >> "${CONFIGFILE}"
    cat "${ICEFILE}" >> "${CONFIGFILE}"
fi

chown -R murmur:nobody /data/

if [ -f "${CUSTOM_CONFIG_FILE}" ]; then
    CONFIGFILE="${CUSTOM_CONFIG_FILE}"
fi

# Run murmur if not in debug mode
if [ -z "$DEBUG" ] || [ "$DEBUG" -ne 1 ]; then
    exec /opt/murmur/murmur.x86 -fg -ini "${CONFIGFILE}"
else
    exec /opt/murmur/murmur.x86 -fg -ini "${CONFIGFILE}" -v
fi

