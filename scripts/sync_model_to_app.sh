#!/usr/bin/env bash
set -e
SRC=ml/exports/v1.0
DST=frontend/mobile_web_flutter/assets/models
mkdir -p "$DST"
cp -r "$SRC"/* "$DST"/
echo "Copied model to Flutter assets."
