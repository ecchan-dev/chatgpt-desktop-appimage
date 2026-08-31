#!/usr/bin/env bash
set -Eeuo pipefail

RPM_URL="${RPM_URL:-https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.x86_64.rpm}"
REPOSITORY="${GITHUB_REPOSITORY:-ecchan-dev/chatgpt-desktop-appimage}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work}"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
APPDIR="${WORK_DIR}/ChatGPT.AppDir"
RPM_FILE="${WORK_DIR}/chatgpt.x86_64.rpm"
OUTPUT="${DIST_DIR}/ChatGPT-x86_64.AppImage"
ZSYNC="${OUTPUT}.zsync"
UPDATE_INFO="gh-releases-zsync|${REPOSITORY%/*}|${REPOSITORY#*/}|latest|$(basename "${ZSYNC}")"

for command_name in curl rpm rpm2cpio cpio file find sed; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "${command_name}" >&2
    exit 1
  }
done

mkdir -p "${WORK_DIR}" "${DIST_DIR}"
rm -rf -- "${APPDIR}"
mkdir -p "${APPDIR}"

printf 'Downloading official ChatGPT RPM...\n'
curl --fail --location --retry 3 --output "${RPM_FILE}" "${RPM_URL}"
file "${RPM_FILE}" | grep -qi 'RPM' || {
  printf 'Downloaded file is not an RPM.\n' >&2
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

for executable in "$APPDIR/opt/ChatGPT/chatgpt" "$APPDIR/opt/chatgpt/chatgpt" "$APPDIR/usr/lib/chatgpt/chatgpt"; do
  if [ -x "$executable" ]; then
    exec "$executable" "$@"
  fi
done

if [ -x "$APPDIR/usr/bin/chatgpt" ]; then
  exec "$APPDIR/usr/bin/chatgpt" "$@"
fi

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
if [[ ! -x "${APPIMAGETOOL}" ]]; then
  curl --fail --location --retry 3 --output "${APPIMAGETOOL}" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod 0755 "${APPIMAGETOOL}"
fi

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

sha256sum "${OUTPUT}" "${ZSYNC}" > "${DIST_DIR}/SHA256SUMS"
printf 'Built %s\n' "${OUTPUT}"
