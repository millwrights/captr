#!/usr/bin/env bash
# Captr — print Markdown release notes for a tag to stdout.
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# Usage: scripts/release-notes.sh <tag> [owner/repo]
# Builds a "What's changed" bullet list from the commit subjects since the
# previous version tag, plus install instructions and a compare link.

set -euo pipefail

TAG="${1:?usage: release-notes.sh <tag> [owner/repo]}"
REPO="${2:-millwrights/captr}"

# Previous version tag = the highest version tag that isn't this one.
PREV="$(git tag --sort=-version:refname | grep -vx "$TAG" | head -1 || true)"
if [ -n "$PREV" ]; then RANGE="$PREV..$TAG"; else RANGE="$TAG"; fi

# Prefer a hand-written notes file if one is committed for this tag; otherwise
# auto-generate a bullet list from the commit subjects.
CURATED="docs/release-notes/$TAG.md"
if [ -f "$CURATED" ]; then
  cat "$CURATED"
  echo
else
  echo "## What's changed"
  echo
  git log --no-merges --pretty=format:'- %s' "$RANGE"
  echo
fi
echo

echo "## Install"
echo
echo "1. Download \`Captr-$TAG.zip\` below and unzip it."
echo "2. Move **Captr.app** to \`/Applications\`."
echo "3. This build is self-signed (not notarized), so the first launch needs a"
echo "   **right-click → Open** to get past Gatekeeper."
echo "4. Grant **Screen Recording** under System Settings → Privacy & Security →"
echo "   Screen Recording, then quit and reopen Captr (macOS applies it on relaunch)."
echo "   Scrolling capture additionally needs **Accessibility**."
echo

if [ -n "$PREV" ]; then
  echo "**Full Changelog**: https://github.com/$REPO/compare/$PREV...$TAG"
fi
