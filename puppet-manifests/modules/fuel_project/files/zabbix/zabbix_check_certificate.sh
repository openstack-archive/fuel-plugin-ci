#!/bin/bash
#
# Source: https://sys4.de/en/blog/2013/08/06/monitoring-certificates-zabbix/
#
# Authors:
#       Michael Schwartzkopff <ms@sys4.de>
#       Marc Schiffbauer <m@sys4.de>
#

trap clean_exit EXIT

clean_exit() {
  [[ $TMP && -f $TMP ]] && rm -f "$TMP"
}

debug() {
  [[ $DEBUG -gt 0 ]] && echo "$*"
}

debugexec() {
  [[ $DEBUG -gt 0 ]] && "$*"
}

error() {
  echo "ERROR: $*"
}

die() {
  error "$*"
  exit 1
}

usage() {
  echo "
  Usage:
  $(basename $0) [options]

  -H <hostname>         Hostname to connect to. Default: localhost
  -P <protocol>         Protocol to use (SSL, SMTP, IMAP, POP3, FTP, XMPP). Default: SSL
  -d                    Turn on debug mode
  -i                    Get certificate issuer instead of days left until certificate will expire
  -p <port>             Port to connect to. Defaults: 443 (SSL), 25 (SMTP), 143 (IMAP),
  110 (POP3), 21 (FTP), 5269 (XMPP)

  "
  exit 0
}

while getopts "idhH:p:P:" opt; do
  case "$opt" in
    H) HOST="$OPTARG";;
    P) PROTO="$OPTARG";;
    d) DEBUG=1; set -x;;
    i) WHAT="ISSUER";;
    p) PORT="$OPTARG";;
    *) usage;;
  esac
done

# set default values
HOST=${HOST:-localhost}
PROTO=${PROTO:-SSL}
WHAT=${WHAT:-TIME}

debug "Checking protocol $PROTO on ${HOST}:${PORT}"

case $PROTO in
  SSL)
  PORT=${PORT:-443}
  S_CLIENT_OPTS=" -host $HOST -port $PORT -showcerts"
  ;;
  SMTP)
  PORT=${PORT:-25}
  S_CLIENT_OPTS="-connect $HOST:$PORT -starttls smtp"
  ;;
  IMAP)
  PORT=${PORT:-143}
  S_CLIENT_OPTS="-connect $HOST:$PORT -starttls imap"
  ;;
  POP3)
  PORT=${PORT:-110}
  S_CLIENT_OPTS="-connect $HOST:$PORT -starttls pop3"
  ;;
  FTP)
  PORT=${PORT:-21}
  S_CLIENT_OPTS="-connect $HOST:$PORT -starttls ftp"
  ;;
  XMPP)
  PORT=${PORT:-5269}
  S_CLIENT_OPTS="-connect $HOST:$PORT -starttls xmpp"
  ;;
  *)
  die "Unknown protocol"
  ;;
esac

debug "Certificate:"
debugexec "openssl s_client $S_CLIENT_OPTS </dev/null 2>$TMP"

case $WHAT in
  TIME)
  TMP="$(mktemp)"
  END_DATE="$(openssl s_client $S_CLIENT_OPTS </dev/null 2>$TMP | openssl x509 -dates -noout | sed -n 's/notAfter=//p')"
  NOW="$(date '+%s')"
  if [[ $END_DATE ]]; then
    SEC_LEFT="$(date '+%s' --date "${END_DATE}")"
    echo $((($SEC_LEFT-$NOW)/24/3600))
  else
    die "openssl error: $(cat $TMP)"
  fi
  ;;
  ISSUER)
  TMP="$(mktemp)"
  openssl s_client $S_CLIENT_OPTS </dev/null 2>$TMP | openssl x509 -issuer -noout | sed -n 's/.*CN=//p'
  ;;
  *)
  die "BUG: unknown WHAT value: $WHAT"
  ;;
esac

exit 0
