cask "captr" do
  version "0.1.0"

  # TODO: Pin this to the real release artifact's checksum once a signed
  # release exists, e.g.:
  #   sha256 "abc123...def"
  # Compute it with: shasum -a 256 Captr-v0.1.0.zip
  sha256 :no_check

  url "https://github.com/millwrights/captr/releases/download/v#{version}/Captr-v#{version}.zip"
  name "Captr"
  desc "Open-source screenshot & annotation app for macOS"
  homepage "https://github.com/millwrights/captr"

  app "Captr.app"

  zap trash: [
    "~/Library/Application Support/Captr",
    "~/Library/Preferences/com.millwrights.captr.plist",
  ]

  caveats <<~EOS
    Captr needs Screen Recording permission to capture your screen. Grant it under:

      System Settings → Privacy & Security → Screen Recording

    You may need to launch Captr once (and quit/relaunch) before it appears in
    that list. Scrolling capture additionally needs Accessibility permission.
  EOS
end
