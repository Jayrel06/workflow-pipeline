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

# Check if we have an optimized version from Stage 3
OPTIMIZED_FILE="05-stage-3-codex/output/${WORKFLOW_NAME}-optimized.json"
ORIGINAL_FILE="03-stage-2-claude-code/output/${WORKFLOW_NAME}.json"

if [ -f "$OPTIMIZED_FILE" ]; then
    WORKFLOW_FILE="$OPTIMIZED_FILE"
    echo "ℹ️  Using optimized version from Stage 3"
else
    WORKFLOW_FILE="$ORIGINAL_FILE"
    echo "ℹ️  No optimized version found, using Stage 2 output"
fi

REPORT_FILE="06-gate-3-quality-performance/reports/${WORKFLOW_NAME}-gate-3-report.md"

mkdir -p "06-gate-3-quality-performance/reports"

if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "❌ Error: Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

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

# Run validators
if command -v node &> /dev/null; then
    echo "✓ Running code quality analysis..."
    node 06-gate-3-quality-performance/validators/code-quality.js "$WORKFLOW_FILE" >> "$REPORT_FILE" 2>&1
    QUALITY_EXIT=$?

    echo "✓ Running performance analysis..."
    node 06-gate-3-quality-performance/validators/performance-analyzer.js "$WORKFLOW_FILE" >> "$REPORT_FILE" 2>&1
    PERF_EXIT=$?

    # If optimized version exists, compare metrics
    if [ -f "$OPTIMIZED_FILE" ] && [ -f "$ORIGINAL_FILE" ]; then
        echo "" >> "$REPORT_FILE"
        echo "## Optimization Comparison" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        ORIG_NODES=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$ORIGINAL_FILE')).nodes.length)" 2>/dev/null || echo "0")
        OPT_NODES=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$OPTIMIZED_FILE')).nodes.length)" 2>/dev/null || echo "0")

        echo "- **Original Nodes**: $ORIG_NODES" >> "$REPORT_FILE"
        echo "- **Optimized Nodes**: $OPT_NODES" >> "$REPORT_FILE"

        if [ $OPT_NODES -lt $ORIG_NODES ]; then
            REDUCTION=$(( (ORIG_NODES - OPT_NODES) * 100 / ORIG_NODES ))
            echo "- **Improvement**: ${REDUCTION}% reduction in nodes" >> "$REPORT_FILE"
        fi
        echo "" >> "$REPORT_FILE"
    fi
else
    echo "⚠ Node.js not available - skipping advanced analysis"
    WARNINGS=$((WARNINGS + 1))
fi

# Final report
echo "" >> "$REPORT_FILE"
echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Errors**: $ERRORS" >> "$REPORT_FILE"
echo "- **Warnings**: $WARNINGS" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ $ERRORS -eq 0 ]; then
    echo "**Status**: ✅ PASSED" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Code quality and performance are acceptable. Ready for Stage 4 (Copilot final review)." >> "$REPORT_FILE"

    if [ -f "pipeline-control/update-status.js" ]; then
        node pipeline-control/update-status.js "$WORKFLOW_NAME" "stage-4" "passed-gate-3" 2>/dev/null || true
    fi

    echo ""
    echo "=========================================="
    echo "✅ Gate 3 PASSED"
    echo "=========================================="
    echo ""
    echo "Next: Stage 4 (Copilot final review)"
    echo "  See: 07-stage-4-copilot/README.md"
    exit 0
else
    echo "**Status**: ❌ FAILED" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Quality issues found. Review and fix before Stage 4." >> "$REPORT_FILE"

    if [ -f "pipeline-control/update-status.js" ]; then
        node pipeline-control/update-status.js "$WORKFLOW_NAME" "stage-3" "failed-gate-3" 2>/dev/null || true
    fi

    echo ""
    echo "=========================================="
    echo "❌ Gate 3 FAILED"
    echo "=========================================="
    echo ""
    echo "See report: $REPORT_FILE"
    exit 1
fi
