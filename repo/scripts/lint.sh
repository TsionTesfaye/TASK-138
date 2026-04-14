#!/bin/bash
set -e

echo ""
echo "========================================="
echo "  DealerOps Static Lint"
echo "========================================="
echo ""

WARNINGS=0

# Check for TODO comments
TODO_COUNT=$(grep -rn "TODO" --include="*.swift" Models/ Repositories/ Persistence/ Services/ App/ Tests/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$TODO_COUNT" -gt 0 ]; then
  echo "⚠️  Found $TODO_COUNT TODO comments:"
  grep -rn "TODO" --include="*.swift" Models/ Repositories/ Persistence/ Services/ App/ Tests/ 2>/dev/null | head -10
  echo ""
  WARNINGS=$((WARNINGS + TODO_COUNT))
fi

# Check for FIXME comments
FIXME_COUNT=$(grep -rn "FIXME" --include="*.swift" Models/ Repositories/ Persistence/ Services/ App/ Tests/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$FIXME_COUNT" -gt 0 ]; then
  echo "⚠️  Found $FIXME_COUNT FIXME comments:"
  grep -rn "FIXME" --include="*.swift" Models/ Repositories/ Persistence/ Services/ App/ Tests/ 2>/dev/null | head -10
  echo ""
  WARNINGS=$((WARNINGS + FIXME_COUNT))
fi

# Check for try? (silent failures) in services
TRYQ_COUNT=$(grep -rn "try? " --include="*.swift" Services/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$TRYQ_COUNT" -gt 0 ]; then
  echo "⚠️  Found $TRYQ_COUNT try? (silent failures) in Services:"
  grep -rn "try? " --include="*.swift" Services/ 2>/dev/null | head -10
  echo ""
  WARNINGS=$((WARNINGS + TRYQ_COUNT))
fi

# Check for print( in services (should use Logger)
PRINT_COUNT=$(grep -rn "print(" --include="*.swift" Services/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$PRINT_COUNT" -gt 0 ]; then
  echo "⚠️  Found $PRINT_COUNT print() in Services (should use Logger):"
  grep -rn "print(" --include="*.swift" Services/ 2>/dev/null | head -10
  echo ""
  WARNINGS=$((WARNINGS + PRINT_COUNT))
fi

# File count summary
SWIFT_COUNT=$(find Models/ Repositories/ Persistence/ Services/ App/ Tests/ -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
echo "📊 Total Swift files: $SWIFT_COUNT"
echo "📊 Warnings: $WARNINGS"
echo ""

if [ "$WARNINGS" -eq 0 ]; then
  echo "✅ Lint passed — no warnings"
else
  echo "⚠️  Lint completed with $WARNINGS warning(s)"
fi
