#!/usr/bin/env bash
set -euo pipefail

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "swiftformat not found. Install with: brew install swiftformat"
  exit 1
fi

swiftformat .
