#!/bin/bash
set -e

echo ""
echo "========================================="
echo "  DealerOps Test Suite"
echo "========================================="
echo ""

# --- Identify UIKit-dependent files to exclude ---
# These files import UIKit which is unavailable outside Xcode/iOS SDK.
# They are excluded from swiftc compilation but remain in the repo for Xcode builds.

EXCLUDE_FILES=(
  "App/AppDelegate.swift"
  "App/BootstrapViewController.swift"
  "App/LoginViewController.swift"
  "App/HomeViewController.swift"
  "App/MainSplitViewController.swift"
  "App/Views/DashboardViewController.swift"
  "App/Views/Leads/LeadListViewController.swift"
  "App/Views/Leads/LeadDetailViewController.swift"
  "App/Views/Leads/CreateLeadViewController.swift"
  "App/Views/Leads/AppointmentListViewController.swift"
  "App/Views/Inventory/InventoryTaskListViewController.swift"
  "App/Views/Inventory/CountEntryViewController.swift"
  "App/Views/Carpool/CarpoolListViewController.swift"
  "App/Views/Compliance/ExceptionListViewController.swift"
  "App/Views/Compliance/CheckInViewController.swift"
  "App/Views/Admin/AdminPanelViewController.swift"
  "App/Views/Admin/PermissionScopeViewController.swift"
  "App/Views/Shared/BaseTableViewController.swift"
  "App/Views/Shared/FormViewController.swift"
  "App/Views/Shared/MediaViewerViewController.swift"
)

# --- Collect all compilable Swift files ---
echo "🔧 Compiling Swift sources..."
echo ""

SOURCES=""

# Models
SOURCES="$SOURCES $(find Models -name '*.swift' | sort | tr '\n' ' ')"

# Repositories
SOURCES="$SOURCES $(find Repositories -name '*.swift' | sort | tr '\n' ' ')"

# Persistence
SOURCES="$SOURCES $(find Persistence -name '*.swift' | sort | tr '\n' ' ')"

# Services (all, including Platform and Contracts)
SOURCES="$SOURCES $(find Services -name '*.swift' | sort | tr '\n' ' ')"

# App layer — only non-UIKit files (ServiceContainer, ViewModels)
SOURCES="$SOURCES App/ServiceContainer.swift"
SOURCES="$SOURCES $(find App/ViewModels -name '*.swift' 2>/dev/null | sort | tr '\n' ' ')"

# Tests
SOURCES="$SOURCES $(find Tests -name '*.swift' | sort | tr '\n' ' ')"

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
