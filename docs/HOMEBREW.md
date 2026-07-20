# Installing Captr with Homebrew

Until Captr is submitted to the main `homebrew-cask` tap, you can install it
straight from this repo's cask.

```sh
brew install --cask millwrights/captr/captr
# or, from a local clone:
brew install --cask ./Casks/captr.rb
```

After install, launch Captr once and grant **Screen Recording** permission under
**System Settings → Privacy & Security → Screen Recording**, then quit and relaunch.

## Publishing a release (maintainers)

1. `make notarize SIGN_IDENTITY="Developer ID Application: … (TEAMID)"`
2. `make release` — tags the commit and uploads the notarized zip.
3. Update `Casks/captr.rb`: bump `version` and replace `sha256 :no_check` with
   the real checksum (`shasum -a 256 build/Captr-vX.Y.Z.zip`).
