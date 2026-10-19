cask "captr" do
  version "0.3.0"
  sha256 "d41f5c415271a75bf735899a8d6c4bb99765c79e44a0a9e9d46c5410b0db0a72"

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
