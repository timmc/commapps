#!/bin/bash
# As dendrite user, build dendrite binaries to location
# /srv/commdata/matrix/dendrite/bin/dendrite-VERSION/
set -eu -o pipefail

cd /srv/commdata/matrix/dendrite

# Temporary build dir
rm -rf build
mkdir -p build


# Download and verify golang

curl -sS --location "https://golang.org/dl/go${GOLANG_VER}.linux-amd64.tar.gz" \
     > "build/golang-${GOLANG_VER}.tar.gz"

sha256sum --check <(echo "${GOLANG_SHA256}  build/golang-${GOLANG_VER}.tar.gz")

mkdir -p "build/golang-${GOLANG_VER}"
tar xzf "build/golang-${GOLANG_VER}.tar.gz" --directory "build/golang-${GOLANG_VER}"


# Download dendrite and build it

git clone "$DENDRITE_REPO_URL" src

cd /srv/commdata/matrix/dendrite/src # push

[ "$(git rev-parse "v${DENDRITE_VER}")" = "${DENDRITE_COMMIT_SHA1}" ] || {
    echo "Unexpected commit SHA for dendrite tag -- did the tag change?"
    exit 1
}
git checkout "v${DENDRITE_VER}"
export PATH="$PATH:/srv/commdata/matrix/dendrite/build/golang-${GOLANG_VER}/go/bin"
./build.sh

cd /srv/commdata/matrix/dendrite # pop


# Move binary into place, signaling completion
mkdir -p bin
mv --no-target-directory src/bin "bin/dendrite-${DENDRITE_VER}"

# Remove temporary stuff -- no need to back this up once binary is built
rm -rf build src
