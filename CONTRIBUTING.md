# Contributing

Run the build locally with:

```bash
./scripts/build-appimage.sh
```

Before proposing a change:

1. Confirm the AppImage launches.
2. Confirm `--appimage-updateinformation` reports this repository.
3. Confirm `dist/ChatGPT-x86_64.AppImage.zsync` exists.
4. Run `sha256sum --check dist/SHA256SUMS`.

Do not commit downloaded RPMs, generated AppImages, credentials, or application data.
