# ChatGPT Desktop AppImage

Unofficial AppImage packaging for the official ChatGPT desktop app for Linux.

This repository downloads OpenAI's current x64 RPM from its official distribution URL, verifies its RPM signature, repackages its files as an AppImage, embeds GitHub release update metadata, smoke-tests the resulting filesystem, and publishes it with GitHub build-provenance attestations.

> [!IMPORTANT]
> This project is not affiliated with, endorsed by, or supported by OpenAI. ChatGPT and OpenAI are trademarks of OpenAI. The packaged application remains subject to the terms and notices included by OpenAI.

## Install with Gear Lever

1. Download `ChatGPT-x86_64.AppImage` from the [latest release](https://github.com/ecchan-dev/chatgpt-desktop-appimage/releases/latest).
2. Open the file with [Gear Lever](https://github.com/mijorus/gearlever).
3. Select **Integrate**.
4. Enable update checks in Gear Lever.

The AppImage embeds this repository as its GitHub Releases update source. Future releases should therefore appear in Gear Lever automatically.

## Security

The build fails unless all of the following succeed:

- The RPM validates against the pinned OpenAI repository signing key.
- The signing-key fingerprint matches the reviewed fingerprint in the build script.
- `appimagetool` matches its pinned SHA-256 digest.
- The AppImage contains its launcher, official ChatGPT executable, and expected update source.
- Release checksums are generated after validation.

GitHub Actions are pinned to immutable commit hashes. Public releases also receive GitHub/Sigstore build-provenance attestations. See [SECURITY.md](SECURITY.md) for verification commands and the trust model.

## Automatic builds

The workflow checks the official RPM every day and can also be started manually from the **Actions** tab. It creates a release only when that RPM and packaging revision have not already been published.

Official RPM source:

```text
https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.x86_64.rpm
```

A legitimate OpenAI signing-key rotation intentionally stops the build until the new key and fingerprint are reviewed.

## Build locally

On a Fedora-like system, install `rpm`, `rpm2cpio`, `cpio`, `curl`, `file`, and `gnupg`, then run:

```bash
bash ./scripts/build-appimage.sh
```

The AppImage, its `.zsync` update file, checksums, and version file are written to `dist/`.

## Architectures

The current workflow builds x86_64 only because the repository was created for the x64 RPM. ARM64 can be added separately using OpenAI's official ARM64 RPM and an ARM64 build runner.

## Redistribution

Before distributing generated release files, repository owners should independently confirm that redistribution is allowed by the terms accompanying the official application. If redistribution is not permitted, disable the release workflow and use the build script locally.
