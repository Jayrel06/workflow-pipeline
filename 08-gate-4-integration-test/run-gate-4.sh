#!/bin/bash
# Gate 4: Final Integration Test

WORKFLOW_NAME=$1

if [ -z "$WORKFLOW_NAME" ]; then
    echo "Usage: ./run-gate-4.sh [workflow-name]"
    exit 1
fi

echo "🚪 Gate 4: Final Integration Test"
echo "Workflow: $WORKFLOW_NAME"
echo "=========================================="
echo ""

STAGE4_DIR="07-stage-4-copilot/output"
FINAL_FILE="${STAGE4_DIR}/${WORKFLOW_NAME}-final.json"
STAGE3_FILE="05-stage-3-codex/output/${WORKFLOW_NAME}-optimized.json"
STAGE2_FILE="03-stage-2-claude-code/output/${WORKFLOW_NAME}.json"
REPORT_FILE="08-gate-4-integration-test/reports/${WORKFLOW_NAME}-gate-4-report.md"

mkdir -p "08-gate-4-integration-test/reports"

# Initialize report
cat > "$REPORT_FILE" << EOF
# Gate 4 Final Integration Test Report
**Workflow**: $WORKFLOW_NAME
**Date**: $(date)
**Status**: In Progress

## Final Validation

EOF

ERRORS=0
WARNINGS=0

# Determine which version is final
WORKFLOW_FILE=""
if [ -f "$FINAL_FILE" ]; then
    WORKFLOW_FILE="$FINAL_FILE"
    echo "✓ Using Stage 4 final version"
    echo "- ✅ Stage 4 final version selected" >> "$REPORT_FILE"
elif [ -f "$STAGE3_FILE" ]; then
    WORKFLOW_FILE="$STAGE3_FILE"
    echo "✓ Using Stage 3 optimized version (no Stage 4 final)"
    echo "- ℹ️  Using Stage 3 optimized version" >> "$REPORT_FILE"
elif [ -f "$STAGE2_FILE" ]; then
    WORKFLOW_FILE="$STAGE2_FILE"
    echo "✓ Using Stage 2 implementation (no optimization)"
    echo "- ℹ️  Using Stage 2 original version" >> "$REPORT_FILE"
else
    echo "❌ Error: No workflow file found!"
    echo "- ❌ **CRITICAL**: No workflow file found" >> "$REPORT_FILE"
    ERRORS=$((ERRORS + 1))
fi

if [ -n "$WORKFLOW_FILE" ] && [ -f "$WORKFLOW_FILE" ]; then
    echo ""
    echo "Testing workflow: $WORKFLOW_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Workflow File**: $WORKFLOW_FILE" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    # Test 1: Valid JSON
    echo ""
    echo "✓ Test 1: Validating JSON syntax..."
    if command -v node &> /dev/null; then
        if node -e "JSON.parse(require('fs').readFileSync('$WORKFLOW_FILE', 'utf8'))" 2>/dev/null; then
            echo "   ✅ Valid JSON"
            echo "- ✅ **JSON Valid**: Syntax is correct" >> "$REPORT_FILE"
        else
            echo "   ❌ Invalid JSON"
            echo "- ❌ **CRITICAL**: Invalid JSON syntax" >> "$REPORT_FILE"
            ERRORS=$((ERRORS + 1))
        fi

        # Test 2: Structure check
        echo ""
        echo "✓ Test 2: Checking n8n structure..."
        WORKFLOW_JSON=$(node -e "console.log(JSON.stringify(JSON.parse(require('fs').readFileSync('$WORKFLOW_FILE', 'utf8'))))" 2>/dev/null)

        if echo "$WORKFLOW_JSON" | grep -q '"nodes"'; then
            NODE_COUNT=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$WORKFLOW_FILE', 'utf8')).nodes.length)" 2>/dev/null)
            echo "   ✅ Found $NODE_COUNT nodes"
            echo "- ✅ **Structure Valid**: $NODE_COUNT nodes found" >> "$REPORT_FILE"
        else
            echo "   ❌ Missing nodes array"
            echo "- ❌ **CRITICAL**: No nodes array" >> "$REPORT_FILE"
            ERRORS=$((ERRORS + 1))
        fi

        # Test 3: Security scan
        echo ""
        echo "✓ Test 3: Final security scan..."
        if [ -f "04-gate-2-structure-security/validators/security-scanner.js" ]; then
            node 04-gate-2-structure-security/validators/security-scanner.js "$WORKFLOW_FILE" >> "$REPORT_FILE" 2>&1
            SEC_EXIT=$?
            if [ $SEC_EXIT -ne 0 ]; then
                echo "   ❌ Security issues found"
                ERRORS=$((ERRORS + 1))
            else
                echo "   ✅ No security issues"
            fi
        fi

        # Test 4: JSON structure
        echo ""
        echo "✓ Test 4: Validating JSON structure..."
        if [ -f "04-gate-2-structure-security/validators/json-structure.js" ]; then
            node 04-gate-2-structure-security/validators/json-structure.js "$WORKFLOW_FILE" >> "$REPORT_FILE" 2>&1
            STRUCT_EXIT=$?
            if [ $STRUCT_EXIT -ne 0 ]; then
                echo "   ❌ Structure issues found"
                ERRORS=$((ERRORS + 1))
            else
                echo "   ✅ Structure valid"
            fi
        fi
    else
        echo "   ⚠ Node.js not available - skipping detailed tests"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Test 5: Check for documentation
    echo ""
    echo "✓ Test 5: Checking documentation..."

    DOCS_FOUND=0
    if [ -f "01-stage-1-claude-desktop/output/${WORKFLOW_NAME}-architecture.md" ]; then
        echo "   ✓ Architecture documentation exists"
        DOCS_FOUND=$((DOCS_FOUND + 1))
    fi

    if [ -f "03-stage-2-claude-code/output/${WORKFLOW_NAME}-implementation-notes.md" ]; then
        echo "   ✓ Implementation documentation exists"
        DOCS_FOUND=$((DOCS_FOUND + 1))
    fi

    if [ -f "03-stage-2-claude-code/output/${WORKFLOW_NAME}-test-payloads.json" ]; then
        echo "   ✓ Test payloads exist"
        DOCS_FOUND=$((DOCS_FOUND + 1))
    fi

    echo "- ℹ️  **Documentation**: $DOCS_FOUND/3 documentation files found" >> "$REPORT_FILE"

    if [ $DOCS_FOUND -lt 2 ]; then
        echo "   ⚠ Missing some documentation"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Final report
echo "" >> "$REPORT_FILE"
echo "## Final Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Total Errors**: $ERRORS" >> "$REPORT_FILE"
echo "- **Total Warnings**: $WARNINGS" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ $ERRORS -eq 0 ]; then
    echo "**Status**: ✅ APPROVED FOR PRODUCTION" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "This workflow has passed all validation gates and is ready for deployment to n8n." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "### Deployment Checklist" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "- [ ] Import workflow to n8n" >> "$REPORT_FILE"
    echo "- [ ] Configure environment variables" >> "$REPORT_FILE"
    echo "- [ ] Test with provided test payloads" >> "$REPORT_FILE"
    echo "- [ ] Activate workflow" >> "$REPORT_FILE"
    echo "- [ ] Monitor initial executions" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Workflow File**: \`$WORKFLOW_FILE\`" >> "$REPORT_FILE"

    echo ""
    echo "=========================================="
    echo "✅ GATE 4 PASSED - APPROVED FOR PRODUCTION"
    echo "=========================================="
    echo ""
    echo "Your workflow is ready to deploy!"
    echo ""
    echo "Next steps:"
    echo "1. Import to n8n: $WORKFLOW_FILE"
    echo "2. Set environment variables"
    echo "3. Test with: 03-stage-2-claude-code/output/${WORKFLOW_NAME}-test-payloads.json"
    echo "4. Activate and monitor"
    echo ""
    exit 0
else
    echo "**Status**: ❌ REJECTED" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Workflow has $ERRORS critical errors and cannot be approved for production." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**DO NOT DEPLOY** until all errors are resolved." >> "$REPORT_FILE"

    echo ""
    echo "=========================================="
    echo "❌ GATE 4 FAILED - $ERRORS errors"
    echo "=========================================="
    echo ""
    echo "Fix errors before deployment!"
    echo "See report: $REPORT_FILE"
    exit 1
fi
