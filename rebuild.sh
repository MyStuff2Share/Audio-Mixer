#!/bin/sh
set -e

cd "$(dirname "$0")"

Scripts/package.sh
rm -rf "/Applications/Audio Mixer.app" /Applications/AudioMixerClone.app
cp -R "dist/Audio Mixer.app" /Applications/
open "/Applications/Audio Mixer.app"
