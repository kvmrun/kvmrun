#!/bin/bash
set -euo pipefail

declare -r SOURCE_DIR="/root/source"
declare -r RESULT_DIR="${SOURCE_DIR}/packages"

cd "${SOURCE_DIR}"

if [[ ! -f "debian/control" ]]; then
    echo "Not found: ${SOURCE_DIR}/debian/control" >&2
    exit 1
fi

# --- build tools (base image is a standard Debian release) ---
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq --no-install-recommends build-essential dpkg-dev debhelper git

# --- version from source ---
declare -r VER="$(sed -n 's/.*Major: \([0-9]\+\), Minor: \([0-9]\+\), Micro: \([0-9]\+\).*/\1.\2.\3/p' kvmrun/version.go)"
if [[ -z "$VER" ]]; then
    echo "ERROR: cannot determine version from kvmrun/version.go" >&2
    exit 1
fi

# --- git info (optional) ---
GIT_COMMIT_REV="$(git show -s --format=%h 2>/dev/null || echo unknown)"
GIT_REMOTE_URL="$(git ls-remote --get-url 2>/dev/null || echo 'local build')"

REVISION="git0"
if [[ "$GIT_COMMIT_REV" != "unknown" ]]; then
REVISION="git$(git rev-list HEAD --count).${GIT_COMMIT_REV}"
fi

# --- isolated build tree (no Makefile: dh_auto_* stay no-op) ---
declare -r BUILD_ROOT="$(mktemp -d)"
declare -r BUILD_DIR="${BUILD_ROOT}/src"

mkdir -p "${BUILD_DIR}"
trap 'rm -rf "$BUILD_ROOT"' EXIT

cp -a debian bin scripts contrib "${BUILD_DIR}/"
cd "${BUILD_DIR}"

# dh_install cannot rename files, so prepare the wrapper under its final name
cp "contrib/qemu.wrapper.debian" "contrib/qemu.wrapper"
chmod 0755 "contrib/qemu.wrapper"

# --- changelog ---
export DEBFULLNAME="Sergey Zhuravlev"
export DEBEMAIL="sergey@netangels.ru"

rm -f "debian/changelog"
cat > "debian/changelog" <<EOF
kvmrun (1:${VER}+${REVISION}) unstable; urgency=low

  * Built from ${GIT_REMOTE_URL} (commit: ${GIT_COMMIT_REV})

 -- ${DEBFULLNAME} <${DEBEMAIL}>  $(date -R)
EOF

# --- build ---
dpkg-buildpackage -b -uc

# --- collect artifacts ---
shopt -s nullglob

declare -a ARTIFACTS=("${BUILD_ROOT}"/kvmrun_*.deb)
if [[ ${#ARTIFACTS[@]} -eq 0 ]]; then
    echo "ERROR: no .deb artifact produced" >&2
    exit 1
fi

install -d "${RESULT_DIR}"
mv -t "${RESULT_DIR}" "${ARTIFACTS[@]}"

exit 0
