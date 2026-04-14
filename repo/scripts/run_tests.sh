#!/bin/bash
set -e

echo ""
echo "========================================="
echo "  DealerOps Test Suite"
echo "========================================="
echo ""

# --- Move to repo root ---
# When invoked as scripts/run_tests.sh from a CI runner, ensure the working
# directory is the repo root (parent of the scripts/ dir), regardless of where
# the script was called from.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# --- swiftc availability / Docker delegation ---
# The project targets iOS (Apple platforms). On a CI host without swiftc, we
# delegate compilation and execution to the Swift Docker container defined in
# docker-compose.yml. Inside that container swiftc IS available, so this branch
# is not taken when the script re-runs itself inside Docker.
if ! command -v swiftc >/dev/null 2>&1; then
  echo "   swiftc not found on host — delegating to Docker (swift:5.9)"
  echo ""
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    exec docker compose -f "$REPO_ROOT/docker-compose.yml" run --rm dealerops
  elif command -v docker-compose >/dev/null 2>&1; then
    exec docker-compose -f "$REPO_ROOT/docker-compose.yml" run --rm dealerops
  else
    echo "❌ Neither swiftc nor docker/docker-compose is available. Cannot run tests."
    exit 127
  fi
fi

# --- Platform detection ---
# CoreData is Apple-only (macOS/iOS). On Linux (e.g. swift:5.9 Docker image) we must
# exclude all CoreData-dependent files from compilation. UIKit files are always excluded
# from command-line compilation (they require Xcode/iOS SDK).
PLATFORM="$(uname -s)"
IS_LINUX=0
if [ "$PLATFORM" = "Linux" ]; then
  IS_LINUX=1
  echo "   Platform: Linux — CoreData sources will be excluded"
else
  echo "   Platform: $PLATFORM — compiling all sources"
fi
echo ""

# --- Collect all compilable Swift files ---
echo "🔧 Compiling Swift sources..."
echo ""

SOURCES=""

# Models — always safe
SOURCES="$SOURCES $(find Models -name '*.swift' | sort | tr '\n' ' ')"

# Repositories — protocols + InMemory implementations, always safe
SOURCES="$SOURCES $(find Repositories -name '*.swift' | sort | tr '\n' ' ')"

# Persistence — all files import CoreData, exclude on Linux
if [ $IS_LINUX -eq 0 ]; then
  SOURCES="$SOURCES $(find Persistence -name '*.swift' | sort | tr '\n' ' ')"
fi

# Services (all, including Platform and Contracts) — safe
SOURCES="$SOURCES $(find Services -name '*.swift' | sort | tr '\n' ' ')"

# App layer — only non-UIKit files.
# ServiceContainer.swift imports CoreData; skip on Linux.
if [ $IS_LINUX -eq 0 ]; then
  SOURCES="$SOURCES App/ServiceContainer.swift"
fi
SOURCES="$SOURCES App/MediaCache.swift"
SOURCES="$SOURCES $(find App/ViewModels -name '*.swift' 2>/dev/null | sort | tr '\n' ' ')"

# Tests — exclude CoreDataIntegrationTests.swift on Linux (imports CoreData)
if [ $IS_LINUX -eq 1 ]; then
  SOURCES="$SOURCES $(find Tests -name '*.swift' -not -name 'CoreDataIntegrationTests.swift' | sort | tr '\n' ' ')"
else
  SOURCES="$SOURCES $(find Tests -name '*.swift' | sort | tr '\n' ' ')"
fi

# Count files
FILE_COUNT=$(echo "$SOURCES" | wc -w | tr -d ' ')
echo "   Files to compile: $FILE_COUNT"
echo ""

# --- Compile ---
swiftc -o run_tests $SOURCES 2>&1
COMPILE_EXIT=$?

if [ $COMPILE_EXIT -ne 0 ]; then
  echo ""
  echo "❌ Compilation FAILED (exit code $COMPILE_EXIT)"
  exit 1
fi

echo "✅ Compilation succeeded"
echo ""

# --- Run tests ---
echo "🧪 Running tests..."
echo ""

./run_tests
TEST_EXIT=$?

if [ $TEST_EXIT -ne 0 ]; then
  echo ""
  echo "❌ Tests FAILED (exit code $TEST_EXIT)"
  exit 1
fi

echo ""
echo "🎉 All tests passed — QA gate clear"
echo ""

# --- Cleanup ---
rm -f run_tests
