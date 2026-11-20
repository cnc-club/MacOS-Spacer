#!/bin/zsh
set -eu
cd "$(dirname "$0")"
mkdir -p .build
swiftc -module-cache-path "${CLANG_MODULE_CACHE_PATH:-$PWD/.build/ModuleCache}" Sources/Spacer/Model.swift Sources/Spacer/Localization.swift Checks/ScannerChecks.swift -o .build/scanner-checks
.build/scanner-checks
