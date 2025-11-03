#!/bin/bash
# Gate 3: Quality & Performance Validation

WORKFLOW_NAME=$1

if [ -z "$WORKFLOW_NAME" ]; then
    echo "Usage: ./run-gate-3.sh [workflow-name]"
    exit 1
fi

echo "🚪 Gate 3: Quality & Performance Validation"
echo "Workflow: $WORKFLOW_NAME"
echo "=========================================="
echo ""

STAGE3_DIR="05-stage-3-codex/output"
OPTIMIZED_FILE="${STAGE3_DIR}/${WORKFLOW_NAME}-optimized.json"
ORIGINAL_FILE="03-stage-2-claude-code/output/${WORKFLOW_NAME}.json"
REPORT_FILE="06-gate-3-quality-performance/reports/${WORKFLOW_NAME}-gate-3-report.md"

mkdir -p "06-gate-3-quality-performance/reports"

# Initialize report
cat > "$REPORT_FILE" << EOF
# Gate 3 Validation Report
**Workflow**: $WORKFLOW_NAME
**Date**: $(date)
**Status**: In Progress

## Validation Results

EOF

ERRORS=0
WARNINGS=0

# Check if optimization was done
if [ ! -f "$OPTIMIZED_FILE" ]; then
    echo "ℹ️  No optimized version found"
    echo "   Either:"
    echo "   1. No optimization was needed (Stage 2 was perfect)"
    echo "   2. Stage 3 was skipped"
    echo "   3. Optimization in progress"
    echo ""
    echo "- ℹ️  **INFO**: No optimized version found at $OPTIMIZED_FILE" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "If Stage 3 optimization was completed, the optimized file should be created." >> "$REPORT_FILE"
    echo "If no optimization was needed, this is acceptable." >> "$REPORT_FILE"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✓ Found optimized version"
    echo "- ✅ Optimized version exists" >> "$REPORT_FILE"
fi

# Validate optimized version (if it exists)
if [ -f "$OPTIMIZED_FILE" ] && command -v node &> /dev/null; then
    echo ""
    echo "✓ Validating optimized workflow..."

    # Check 1: Valid JSON
    if node -e "JSON.parse(require('fs').readFileSync('$OPTIMIZED_FILE', 'utf8'))" 2>/dev/null; then
        echo "   ✓ Valid JSON syntax"
        echo "- ✅ Optimized version has valid JSON" >> "$REPORT_FILE"
    else
        echo "   ❌ Invalid JSON syntax in optimized version"
        echo "- ❌ **CRITICAL**: Optimized version has invalid JSON syntax" >> "$REPORT_FILE"
        ERRORS=$((ERRORS + 1))
    fi

    # Check 2: Compare node count
    if [ -f "$ORIGINAL_FILE" ]; then
        ORIGINAL_NODES=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$ORIGINAL_FILE', 'utf8')).nodes.length)" 2>/dev/null || echo "0")
        OPTIMIZED_NODES=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$OPTIMIZED_FILE', 'utf8')).nodes.length)" 2>/dev/null || echo "0")

        echo ""
        echo "✓ Comparing versions..."
        echo "   Original nodes: $ORIGINAL_NODES"
        echo "   Optimized nodes: $OPTIMIZED_NODES"

        echo "" >> "$REPORT_FILE"
        echo "### Comparison" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        echo "| Metric | Stage 2 (Original) | Stage 3 (Optimized) | Change |" >> "$REPORT_FILE"
        echo "|--------|-------------------|---------------------|--------|" >> "$REPORT_FILE"
        echo "| Nodes  | $ORIGINAL_NODES | $OPTIMIZED_NODES | $((OPTIMIZED_NODES - ORIGINAL_NODES)) |" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        if [ "$OPTIMIZED_NODES" -gt "$((ORIGINAL_NODES * 2))" ]; then
            echo "   ⚠ Optimized version has significantly MORE nodes"
            echo "- ⚠ **WARNING**: Optimized version has $((OPTIMIZED_NODES - ORIGINAL_NODES)) more nodes" >> "$REPORT_FILE"
            WARNINGS=$((WARNINGS + 1))
        elif [ "$OPTIMIZED_NODES" -lt "$ORIGINAL_NODES" ]; then
            echo "   ✓ Optimized version reduced node count"
        fi
    fi

    # Check 3: Run same security scan as Gate 2
    echo ""
    echo "✓ Running security scan on optimized version..."
    if [ -f "04-gate-2-structure-security/validators/security-scanner.js" ]; then
        node 04-gate-2-structure-security/validators/security-scanner.js "$OPTIMIZED_FILE" >> "$REPORT_FILE" 2>&1
        SEC_EXIT=$?
        if [ $SEC_EXIT -ne 0 ]; then
            echo "   ❌ Security issues in optimized version"
            ERRORS=$((ERRORS + 1))
        else
            echo "   ✓ No security issues"
        fi
    fi
fi

# Check for optimization report
REPORT_EXISTS="${STAGE3_DIR}/${WORKFLOW_NAME}-optimization-report.md"
if [ -f "$REPORT_EXISTS" ]; then
    echo ""
    echo "✓ Found optimization report"
    echo "- ✅ Optimization report exists" >> "$REPORT_FILE"
else
    echo ""
    echo "⚠ No optimization report found"
    echo "- ⚠ **WARNING**: No optimization report at $REPORT_EXISTS" >> "$REPORT_FILE"
    WARNINGS=$((WARNINGS + 1))
fi

# Final report
echo "" >> "$REPORT_FILE"
echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Total Errors**: $ERRORS" >> "$REPORT_FILE"
echo "- **Total Warnings**: $WARNINGS" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ $ERRORS -eq 0 ]; then
    echo "**Status**: ✅ PASSED" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    if [ -f "$OPTIMIZED_FILE" ]; then
        echo "Optimization validated. Ready for Stage 4 (Final Review)." >> "$REPORT_FILE"
    else
        echo "No optimization performed. Stage 2 version proceeds to Stage 4." >> "$REPORT_FILE"
    fi

    if [ -f "pipeline-control/update-status.js" ]; then
        node pipeline-control/update-status.js "$WORKFLOW_NAME" "stage-4" "passed-gate-3" 2>/dev/null || true
    fi

    echo ""
    echo "=========================================="
    echo "✅ Gate 3 PASSED"
    echo "=========================================="
    echo ""
    echo "Next step: Stage 4 (Copilot Final Review)"
    echo "  See: 07-stage-4-copilot/README.md"
    exit 0
else
    echo "**Status**: ❌ FAILED" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Optimization introduced $ERRORS errors. Must fix before Stage 4." >> "$REPORT_FILE"

    if [ -f "pipeline-control/update-status.js" ]; then
        node pipeline-control/update-status.js "$WORKFLOW_NAME" "stage-3" "failed-gate-3" 2>/dev/null || true
    fi

    echo ""
    echo "=========================================="
    echo "❌ Gate 3 FAILED - $ERRORS errors"
    echo "=========================================="
    echo ""
    echo "See report: $REPORT_FILE"
    exit 1
fi
