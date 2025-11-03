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
WORKFLOW_FILE="${STAGE2_DIR}/${WORKFLOW_NAME}.json"
REPORT_FILE="04-gate-2-structure-security/reports/${WORKFLOW_NAME}-gate-2-report.md"

mkdir -p "04-gate-2-structure-security/reports"

if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "❌ Error: Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

# Initialize report
cat > "$REPORT_FILE" << EOF
# Gate 2 Validation Report
**Workflow**: $WORKFLOW_NAME
**Date**: $(date)
**Status**: In Progress

## Validation Results

EOF

ERRORS=0
WARNINGS=0

# Check 1: Valid JSON syntax
echo "✓ Validating JSON syntax..."
if command -v node &> /dev/null; then
    if node -e "JSON.parse(require('fs').readFileSync('$WORKFLOW_FILE', 'utf8'))" 2>/dev/null; then
        echo "   ✓ Valid JSON syntax"
        echo "- ✅ JSON syntax valid" >> "$REPORT_FILE"
    else
        echo "   ❌ Invalid JSON syntax"
        echo "- ❌ **CRITICAL**: Invalid JSON syntax" >> "$REPORT_FILE"
        ERRORS=$((ERRORS + 1))
    fi

    # Check 2: Run JSON structure validator
    if [ -f "04-gate-2-structure-security/validators/json-structure.js" ]; then
        echo ""
        echo "✓ Running JSON structure validation..."
        node 04-gate-2-structure-security/validators/json-structure.js "$WORKFLOW_FILE" >> "$REPORT_FILE" 2>&1
        JSON_EXIT=$?
        if [ $JSON_EXIT -ne 0 ]; then
            ERRORS=$((ERRORS + 1))
        fi
    fi

    # Check 3: Run security scanner
    if [ -f "04-gate-2-structure-security/validators/security-scanner.js" ]; then
        echo ""
        echo "✓ Running security scan..."
        node 04-gate-2-structure-security/validators/security-scanner.js "$WORKFLOW_FILE" >> "$REPORT_FILE" 2>&1
        SEC_EXIT=$?
        if [ $SEC_EXIT -ne 0 ]; then
            ERRORS=$((ERRORS + 1))
        fi
    fi
else
    echo "   ⚠ Node.js not found - cannot validate JSON"
    echo "- ⚠ **WARNING**: Node.js not available for validation" >> "$REPORT_FILE"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 4: Basic security scan (even without Node.js)
echo ""
echo "✓ Scanning for obvious hardcoded credentials..."
if grep -iE "(api[_-]?key|password|secret|token).*:.*[\"'][a-zA-Z0-9]{10,}" "$WORKFLOW_FILE" > /dev/null; then
    echo "   ⚠ Possible hardcoded credentials detected"
    echo "- ⚠ **WARNING**: Possible hardcoded credentials - verify all use environment variables" >> "$REPORT_FILE"
    WARNINGS=$((WARNINGS + 1))
else
    echo "   ✓ No obvious hardcoded credentials"
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
    echo "Next step: Stage 3 (Codex/Copilot Optimization)"
    echo "  See: 05-stage-3-codex/README.md"
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
