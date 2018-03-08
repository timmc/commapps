#!/bin/bash
# Install the cert file that has been deposited as
# ~cert-recv/recv/$1.chain.pem if it has changed.
#
# Usage: $0 <domain.name>

set -eu -o pipefail

DOMAIN=$1

src_dir=/home/cert-recv/recv
dest_dir=/opt/commdata/jabber/tls

function install {
  hash_src=`sha256sum < "$1"`
  hash_dest=`sha256sum < "$2"`
  if [[ "$hash_src" = "$hash_dest" ]]; then
    echo "Not installing file, hasn't changed: $1 -> $2"
    return 2
  fi
  echo "Installing file: $1 -> $2"

  touch -- "$2"
  chown prosody:prosody -- "$2"
  chmod o= -- "$2"
  cat < "$1" > "$2"

  return 0
}

if install "$src_dir/$DOMAIN.chain.pem" "$dest_dir/$DOMAIN.chain.pem";
then
  echo "Restarting prosody"
  service prosody stop
  service prosody start
else
  echo "Nothing to do"
fi
