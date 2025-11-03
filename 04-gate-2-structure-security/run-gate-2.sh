#!/bin/bash
# Gate 2: Structure & Security Validation

WORKFLOW_NAME=$1

if [ -z "$WORKFLOW_NAME" ]; then
    echo "Usage: ./run-gate-2.sh [workflow-name]"
    exit 1
fi

echo "🚪 Gate 2: Structure & Security Validation"
echo "Workflow: $WORKFLOW_NAME"
echo "=========================================="
echo ""

STAGE2_DIR="03-stage-2-claude-code/output"
REPORT_FILE="04-gate-2-structure-security/reports/${WORKFLOW_NAME}-gate-2-report.md"

mkdir -p "04-gate-2-structure-security/reports"

cat > "$REPORT_FILE" << EOF
# Gate 2 Validation Report
**Workflow**: $WORKFLOW_NAME
**Date**: $(date)
**Status**: In Progress

## Validation Results

EOF

ERRORS=0
WARNINGS=0

# Check 1: Required files exist
echo "✓ Checking required files..."
REQUIRED_FILES=(
    "${STAGE2_DIR}/${WORKFLOW_NAME}.json"
    "${STAGE2_DIR}/${WORKFLOW_NAME}-test-payloads.json"
    "${STAGE2_DIR}/${WORKFLOW_NAME}-implementation-notes.md"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing: $file"
        echo "- ❌ **CRITICAL**: Missing $file" >> "$REPORT_FILE"
        ERRORS=$((ERRORS + 1))
    else
        echo "   ✓ Found: $file"
    fi
done

# Check 2: Valid JSON syntax
echo ""
echo "✓ Validating JSON syntax..."
WORKFLOW_FILE="${STAGE2_DIR}/${WORKFLOW_NAME}.json"

if [ -f "$WORKFLOW_FILE" ]; then
    if command -v node &> /dev/null; then
        if node -e "JSON.parse(require('fs').readFileSync('$WORKFLOW_FILE', 'utf8'))" 2>/dev/null; then
            echo "   ✓ Valid JSON syntax"
        else
            echo "   ❌ Invalid JSON syntax"
            echo "- ❌ **CRITICAL**: Invalid JSON syntax in workflow file" >> "$REPORT_FILE"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo "   ⚠ Node.js not found - cannot validate JSON"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Check 3: Security scan for hardcoded credentials
echo ""
echo "✓ Scanning for hardcoded credentials..."

if [ -f "$WORKFLOW_FILE" ]; then
    # Check for common credential patterns
    if grep -iE "(api[_-]?key|password|secret|token).*:.*[\"'][a-zA-Z0-9]{10,}" "$WORKFLOW_FILE" > /dev/null; then
        echo "   ⚠ Possible hardcoded credentials detected"
        echo "- ⚠ **WARNING**: Possible hardcoded credentials - verify all use environment variables" >> "$REPORT_FILE"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "   ✓ No obvious hardcoded credentials"
    fi
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
    echo "Workflow structure and security checks passed. Ready for Stage 3 (Codex optimization)." >> "$REPORT_FILE"

    if [ -f "pipeline-control/update-status.js" ]; then
        node pipeline-control/update-status.js "$WORKFLOW_NAME" "stage-3" "passed-gate-2" 2>/dev/null || true
    fi

    echo ""
    echo "=========================================="
    echo "✅ Gate 2 PASSED"
    echo "=========================================="
    echo ""
    echo "Next step: Run Stage 3 (Codex)"
    echo "  cd 05-stage-3-codex"
    echo "  # Use prompts/refinement-prompt.md with Codex"
    exit 0
else
    echo "**Status**: ❌ FAILED" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Workflow has $ERRORS errors. Must fix before Stage 3." >> "$REPORT_FILE"

    if [ -f "pipeline-control/update-status.js" ]; then
        node pipeline-control/update-status.js "$WORKFLOW_NAME" "stage-2" "failed-gate-2" 2>/dev/null || true
    fi

    echo ""
    echo "=========================================="
    echo "❌ Gate 2 FAILED - $ERRORS errors"
    echo "=========================================="
    echo ""
    echo "See report: $REPORT_FILE"
    exit 1
fi
