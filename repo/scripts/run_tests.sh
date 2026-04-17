#!/bin/bash
set -e

echo ""
echo "========================================="
echo "  DealerOps Test Suite"
echo "========================================="
echo ""

# --- Move to repo root ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# --- macOS only ---
# This is an iOS project. The full test suite requires macOS with Xcode command-line
# tools: it uses CoreData, UIKit-backed ViewModels, and the full Apple SDK.
# Running on any other platform (Linux CI, Docker, etc.) is not supported.
PLATFORM="$(uname -s)"
if [ "$PLATFORM" != "Darwin" ]; then
  echo "  This project's test suite requires macOS with Xcode command-line tools."
  echo ""
  echo "  Why: the suite compiles CoreData persistence, UIKit-backed ViewModels,"
  echo "  and Apple-SDK services that have no cross-platform equivalents."
  echo ""
  echo "  To run the tests, use a macOS machine or a macOS CI runner (e.g."
  echo "  GitHub Actions macos-latest) and re-run this script."
  echo ""
  exit 0
fi

# --- swiftc availability check ---
if ! command -v swiftc >/dev/null 2>&1; then
  echo "  swiftc not found. Install Xcode command-line tools:"
  echo ""
  echo "      xcode-select --install"
  echo ""
  exit 1
fi

echo "   Platform: macOS — compiling full suite"
echo ""

# --- Collect all Swift sources ---
echo "Compiling Swift sources..."
echo ""

SOURCES=""
SOURCES="$SOURCES $(find Models      -name '*.swift' | sort | tr '\n' ' ')"
SOURCES="$SOURCES $(find Repositories -name '*.swift' | sort | tr '\n' ' ')"
SOURCES="$SOURCES $(find Persistence  -name '*.swift' | sort | tr '\n' ' ')"
SOURCES="$SOURCES $(find Services     -name '*.swift' | sort | tr '\n' ' ')"
SOURCES="$SOURCES App/ServiceContainer.swift"
SOURCES="$SOURCES $(find App/ViewModels -name '*.swift' 2>/dev/null | sort | tr '\n' ' ')"
SOURCES="$SOURCES App/MediaCache.swift"
SOURCES="$SOURCES $(find Tests -name '*.swift' | sort | tr '\n' ' ')"

FILE_COUNT=$(echo "$SOURCES" | wc -w | tr -d ' ')
echo "   Files to compile: $FILE_COUNT"
echo ""

# --- Compile ---
swiftc -o run_tests $SOURCES 2>&1
COMPILE_EXIT=$?

if [ $COMPILE_EXIT -ne 0 ]; then
  echo ""
  echo "Compilation FAILED (exit code $COMPILE_EXIT)"
  exit 1
fi

echo "Compilation succeeded"
echo ""

# --- Run ---
echo "Running tests..."
echo ""

./run_tests
TEST_EXIT=$?

rm -f run_tests

if [ $TEST_EXIT -ne 0 ]; then
  echo ""
  echo "Tests FAILED (exit code $TEST_EXIT)"
  exit 1
fi

echo ""
echo "All tests passed — QA gate clear"
echo ""
