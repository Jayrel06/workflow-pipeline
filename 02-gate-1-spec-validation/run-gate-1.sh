#!/bin/bash
# Gate 1: Specification Validation
# Checks if Stage 1 (Claude Desktop) produced complete, valid architecture

WORKFLOW_NAME=$1

if [ -z "$WORKFLOW_NAME" ]; then
    echo "Usage: ./run-gate-1.sh [workflow-name]"
    exit 1
fi

echo "🚪 Gate 1: Specification Validation"
echo "Workflow: $WORKFLOW_NAME"
echo "=========================================="
echo ""

STAGE1_DIR="01-stage-1-claude-desktop/output"
REPORT_FILE="02-gate-1-spec-validation/reports/${WORKFLOW_NAME}-gate-1-report.md"

# Create report directory
mkdir -p "02-gate-1-spec-validation/reports"

# Initialize report
cat > "$REPORT_FILE" << EOF
# Gate 1 Validation Report
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
    "${STAGE1_DIR}/${WORKFLOW_NAME}-architecture.md"
    "${STAGE1_DIR}/${WORKFLOW_NAME}-implementation-guide.md"
    "${STAGE1_DIR}/${WORKFLOW_NAME}-test-specs.md"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing required file: $file"
        echo "- ❌ **CRITICAL**: Missing $file" >> "$REPORT_FILE"
        ERRORS=$((ERRORS + 1))
    else
        echo "   ✓ Found: $file"
    fi
done

# Check 2: Architecture document completeness
echo ""
echo "✓ Checking architecture document completeness..."
ARCH_FILE="${STAGE1_DIR}/${WORKFLOW_NAME}-architecture.md"

if [ -f "$ARCH_FILE" ]; then
    REQUIRED_SECTIONS=(
        "Executive Summary"
        "System Overview"
        "n8n Node Architecture"
        "Data Flow Specification"
        "Connection Map"
        "Error Handling Strategy"
        "Security Architecture"
        "Performance Considerations"
        "Environment Variables Needed"
        "Test Strategy"
        "Assumptions & Constraints"
        "Alternative Approaches Considered"
    )

    for section in "${REQUIRED_SECTIONS[@]}"; do
        if ! grep -q "$section" "$ARCH_FILE"; then
            echo "   ❌ Missing section: $section"
            echo "- ❌ **HIGH**: Architecture missing section: $section" >> "$REPORT_FILE"
            ERRORS=$((ERRORS + 1))
        else
            echo "   ✓ Found section: $section"
        fi
    done
fi

# Check 3: Run JavaScript validators (if Node.js available)
echo ""
if command -v node &> /dev/null; then
    echo "✓ Running specification validators..."

    # Note: JavaScript validators will be created separately
    # For now, we'll skip if they don't exist
    if [ -f "02-gate-1-spec-validation/validators/spec-completeness.js" ]; then
        node 02-gate-1-spec-validation/validators/spec-completeness.js "$WORKFLOW_NAME" >> "$REPORT_FILE" 2>&1
        SPEC_EXIT=$?
        if [ $SPEC_EXIT -ne 0 ]; then
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo "   ⚠ Validator scripts not yet implemented (optional)"
    fi
else
    echo "   ⚠ Node.js not found - skipping advanced validators"
    echo "- ⚠ **WARNING**: Advanced validators skipped (Node.js not available)" >> "$REPORT_FILE"
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
    echo "Architecture is complete and ready for Stage 2 (Claude Code implementation)." >> "$REPORT_FILE"

    # Update pipeline status (if script exists)
    if [ -f "pipeline-control/update-status.js" ]; then
        node pipeline-control/update-status.js "$WORKFLOW_NAME" "stage-2" "passed-gate-1" 2>/dev/null || true
    fi

    echo ""
    echo "=========================================="
    echo "✅ Gate 1 PASSED"
    echo "=========================================="
    echo ""
    echo "Next step: Run Stage 2 (Claude Code)"
    echo "  cd 03-stage-2-claude-code"
    echo "  # Use prompts/implementation-prompt.md with Claude Code"
    exit 0
else
    echo "**Status**: ❌ FAILED" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Architecture has $ERRORS errors that must be fixed before proceeding to Stage 2." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "### Required Actions" >> "$REPORT_FILE"
    echo "1. Address all errors listed above" >> "$REPORT_FILE"
    echo "2. Re-run Gate 1 validation" >> "$REPORT_FILE"
    echo "3. Do not proceed to Stage 2 until this passes" >> "$REPORT_FILE"

    # Update pipeline status (if script exists)
    if [ -f "pipeline-control/update-status.js" ]; then
        node pipeline-control/update-status.js "$WORKFLOW_NAME" "stage-1" "failed-gate-1" 2>/dev/null || true
    fi

    echo ""
    echo "=========================================="
    echo "❌ Gate 1 FAILED - $ERRORS errors found"
    echo "=========================================="
    echo ""
    echo "See report: $REPORT_FILE"
    echo ""
    echo "Fix errors in Stage 1 output, then re-run:"
    echo "  ./02-gate-1-spec-validation/run-gate-1.sh $WORKFLOW_NAME"
    exit 1
fi
