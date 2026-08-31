# Security

## Trust model

This project repackages OpenAI's official, signed Linux RPM without modifying the application payload. The build fails unless the RPM validates against the pinned OpenAI repository signing key with fingerprint:

```text
3BFA 0E4A E8B8 CC16 A2D9 BA68 4A3B 4A56 6C46 60E4
```

The key was extracted from the repository configuration installed by OpenAI's official RPM. A future legitimate key rotation intentionally requires a reviewed repository change.

The AppImage build tool is checked against a pinned SHA-256 digest. GitHub Actions are pinned to complete commit hashes, and release files receive GitHub build-provenance attestations.

## Verify a release

After installing the GitHub CLI:

```bash
gh attestation verify ChatGPT-x86_64.AppImage --repo ecchan-dev/chatgpt-desktop-appimage
sha256sum --check SHA256SUMS
```

Checksums detect file corruption. The GitHub attestation additionally connects the binary to this repository, workflow, commit, and build identity.

## Reporting a vulnerability

Please do not publish secrets, tokens, or personal application data in a public issue. Report packaging vulnerabilities through GitHub's private vulnerability-reporting feature if it is enabled. Application vulnerabilities in ChatGPT itself should be reported to OpenAI.
