#!/usr/bin/env bash
set -Eeuo pipefail

RPM_URL="${RPM_URL:-https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.x86_64.rpm}"
REPOSITORY="${GITHUB_REPOSITORY:-ecchan-dev/chatgpt-desktop-appimage}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work}"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
APPDIR="${WORK_DIR}/ChatGPT.AppDir"
RPM_FILE="${WORK_DIR}/chatgpt.x86_64.rpm"
KEY_FILE="${ROOT_DIR}/keys/openai-chatgpt.asc"
EXPECTED_KEY_FINGERPRINT="3BFA0E4AE8B8CC16A2D9BA684A3B4A566C4660E4"
APPIMAGETOOL_SHA256="a6d71e2b6cd66f8e8d16c37ad164658985e0cf5fcaa950c90a482890cb9d13e0"
OUTPUT="${DIST_DIR}/ChatGPT-x86_64.AppImage"
ZSYNC="${OUTPUT}.zsync"
UPDATE_INFO="gh-releases-zsync|${REPOSITORY%/*}|${REPOSITORY#*/}|latest|$(basename "${ZSYNC}")"

for command_name in awk cpio curl file find gpg readelf rpm rpm2cpio sed sha256sum; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "${command_name}" >&2
    exit 1
  }
done

[[ -f "${KEY_FILE}" ]] || {
  printf 'Pinned OpenAI signing key is missing.\n' >&2
  exit 1
}

actual_fingerprint="$(gpg --batch --show-keys --with-colons "${KEY_FILE}" | awk -F: '$1 == "fpr" { print $10; exit }')"
[[ "${actual_fingerprint}" == "${EXPECTED_KEY_FINGERPRINT}" ]] || {
  printf 'Pinned key fingerprint mismatch: %s\n' "${actual_fingerprint}" >&2
  exit 1
}

mkdir -p "${WORK_DIR}" "${DIST_DIR}"
rm -rf -- "${APPDIR}" "${WORK_DIR}/rpmdb"
mkdir -p "${APPDIR}" "${WORK_DIR}/rpmdb"

printf 'Downloading official ChatGPT RPM...\n'
curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --output "${RPM_FILE}" "${RPM_URL}"
file "${RPM_FILE}" | grep -qi 'RPM' || {
  printf 'Downloaded file is not an RPM.\n' >&2
  exit 1
}

printf 'Verifying RPM signature against pinned OpenAI key...\n'
rpm --dbpath "${WORK_DIR}/rpmdb" --initdb
rpm --dbpath "${WORK_DIR}/rpmdb" --import "${KEY_FILE}"
signature_result="$(rpm --dbpath "${WORK_DIR}/rpmdb" --checksig "${RPM_FILE}")"
printf '%s\n' "${signature_result}"
grep -q 'digests signatures OK' <<<"${signature_result}" || {
  printf 'RPM signature verification failed.\n' >&2
  exit 1
}

VERSION="$(rpm -qp --queryformat '%{VERSION}-%{RELEASE}' "${RPM_FILE}")"
printf '%s\n' "${VERSION}" > "${DIST_DIR}/version.txt"

printf 'Extracting RPM version %s...\n' "${VERSION}"
(
  cd "${APPDIR}"
  rpm2cpio "${RPM_FILE}" | cpio -idm --quiet
)

cat > "${APPDIR}/AppRun" <<'APP_RUN'
#!/bin/sh
set -eu
APPDIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
export PATH="$APPDIR/usr/bin:$APPDIR/usr/sbin:$PATH"
export LD_LIBRARY_PATH="$APPDIR/usr/lib64:$APPDIR/usr/lib:$APPDIR/lib64:$APPDIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [ -x "$APPDIR/usr/lib/chatgpt/codex-launcher" ]; then
  exec "$APPDIR/usr/lib/chatgpt/codex-launcher" "$@"
fi

for executable in "$APPDIR/usr/lib/chatgpt/ChatGPT" "$APPDIR/opt/ChatGPT/chatgpt" "$APPDIR/opt/chatgpt/chatgpt"; do
  if [ -x "$executable" ]; then
    exec "$executable" "$@"
  fi
done

printf 'Unable to locate the ChatGPT executable inside the AppImage.\n' >&2
exit 1
APP_RUN
chmod 0755 "${APPDIR}/AppRun"

desktop_source="$(find "${APPDIR}" -type f -name '*.desktop' -print -quit)"
[[ -n "${desktop_source}" ]] || {
  printf 'No desktop entry found in RPM.\n' >&2
  exit 1
}
cp -- "${desktop_source}" "${APPDIR}/chatgpt.desktop"
sed -i -e 's/^Exec=.*/Exec=AppRun %U/' -e 's/^Icon=.*/Icon=chatgpt/' "${APPDIR}/chatgpt.desktop"

icon_source="$(find "${APPDIR}" -type f \( -iname 'chatgpt.svg' -o -iname 'chatgpt.png' \) -print | head -n 1)"
[[ -n "${icon_source}" ]] || {
  printf 'No ChatGPT icon found in RPM.\n' >&2
  exit 1
}
icon_extension="${icon_source##*.}"
cp -- "${icon_source}" "${APPDIR}/chatgpt.${icon_extension}"
ln -sfn "chatgpt.${icon_extension}" "${APPDIR}/.DirIcon"

APPIMAGETOOL="${WORK_DIR}/appimagetool-x86_64.AppImage"
if [[ ! -f "${APPIMAGETOOL}" ]]; then
  curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --output "${APPIMAGETOOL}" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
fi
printf '%s  %s\n' "${APPIMAGETOOL_SHA256}" "${APPIMAGETOOL}" | sha256sum --check --status || {
  printf 'appimagetool checksum verification failed.\n' >&2
  exit 1
}
chmod 0755 "${APPIMAGETOOL}"

rm -f -- "${OUTPUT}" "${ZSYNC}"
printf 'Building AppImage with Gear Lever update metadata...\n'
(
  cd "${DIST_DIR}"
  ARCH=x86_64 VERSION="${VERSION}" "${APPIMAGETOOL}" --appimage-extract-and-run -u "${UPDATE_INFO}" "${APPDIR}" "$(basename "${OUTPUT}")"
)

[[ -s "${OUTPUT}" ]] || {
  printf 'AppImage build failed.\n' >&2
  exit 1
}
[[ -s "${ZSYNC}" ]] || {
  printf 'The zsync update file was not generated.\n' >&2
  exit 1
}

printf 'Running structural AppImage smoke tests...\n'
readelf --string-dump=.upd_info "${OUTPUT}" | grep -F -- "${UPDATE_INFO}" >/dev/null || {
  printf 'Embedded update information mismatch.\n' >&2
  exit 1
}
SMOKE_DIR="${WORK_DIR}/smoke-test"
rm -rf -- "${SMOKE_DIR}"
mkdir -p "${SMOKE_DIR}"
(
  cd "${SMOKE_DIR}"
  "${OUTPUT}" --appimage-extract AppRun >/dev/null
  "${OUTPUT}" --appimage-extract usr/lib/chatgpt/ChatGPT >/dev/null
  "${OUTPUT}" --appimage-extract usr/lib/chatgpt/codex-launcher >/dev/null
  test -x squashfs-root/AppRun
  test -x squashfs-root/usr/lib/chatgpt/ChatGPT
  test -x squashfs-root/usr/lib/chatgpt/codex-launcher
)

sha256sum "${OUTPUT}" "${ZSYNC}" > "${DIST_DIR}/SHA256SUMS"
printf 'Built and verified %s\n' "${OUTPUT}"
