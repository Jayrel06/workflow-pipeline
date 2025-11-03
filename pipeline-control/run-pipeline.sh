#!/bin/bash
# Main Pipeline Controller

WORKFLOW_NAME=$1

if [ -z "$WORKFLOW_NAME" ]; then
    echo "Usage: ./run-pipeline.sh [workflow-name]"
    echo ""
    echo "This script runs the complete pipeline for a workflow:"
    echo "  Stage 1 → Gate 1 → Stage 2 → Gate 2 → Stage 3 → Gate 3 → Stage 4 → Gate 4"
    echo ""
    echo "The workflow description must exist in: 00-input/pending/[workflow-name].md"
    exit 1
fi

INPUT_FILE="00-input/pending/${WORKFLOW_NAME}.md"

if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Error: Workflow description not found"
    echo "Expected: $INPUT_FILE"
    exit 1
fi

echo "🚀 Starting Multi-AI Pipeline"
echo "Workflow: $WORKFLOW_NAME"
echo "=========================================="
echo ""
echo "📋 This pipeline will guide you through 4 stages:"
echo ""
echo "  Stage 1: Claude Desktop (Architecture)"
echo "  Gate 1:  Specification Validation"
echo "  Stage 2: Claude Code (Implementation)"
echo "  Gate 2:  Structure & Security Check"
echo "  Stage 3: Codex (Optimization)"
echo "  Gate 3:  Quality & Performance Check"
echo "  Stage 4: Copilot (Final Review)"
echo "  Gate 4:  Integration Test"
echo ""
echo "=========================================="
echo ""
echo "👉 STAGE 1: Claude Desktop Architecture"
echo ""
echo "Open this file in Claude Desktop:"
echo "  $INPUT_FILE"
echo ""
echo "Use this prompt:"
echo "  01-stage-1-claude-desktop/prompts/architecture-prompt.md"
echo ""
echo "Claude Desktop will create architecture in:"
echo "  01-stage-1-claude-desktop/output/"
echo ""
read -p "Press Enter when Stage 1 is complete..."

# Run Gate 1
echo ""
echo "🚪 Running Gate 1: Specification Validation..."
./02-gate-1-spec-validation/run-gate-1.sh "$WORKFLOW_NAME"
GATE1_EXIT=$?

if [ $GATE1_EXIT -ne 0 ]; then
    echo ""
    echo "❌ Gate 1 failed. Fix errors and run pipeline again."
    exit 1
fi

echo ""
echo "👉 STAGE 2: Claude Code Implementation"
echo ""
echo "Run Claude Code with this prompt:"
echo "  03-stage-2-claude-code/prompts/implementation-prompt.md"
echo ""
echo "Claude Code will create workflow JSON in:"
echo "  03-stage-2-claude-code/output/"
echo ""
read -p "Press Enter when Stage 2 is complete..."

# Run Gate 2
echo ""
echo "🚪 Running Gate 2: Structure & Security Check..."
./04-gate-2-structure-security/run-gate-2.sh "$WORKFLOW_NAME"
GATE2_EXIT=$?

if [ $GATE2_EXIT -ne 0 ]; then
    echo ""
    echo "❌ Gate 2 failed. Fix errors and rerun from Stage 2."
    exit 1
fi

echo ""
echo "👉 STAGE 3: Codex Optimization"
echo ""
echo "Use Codex with this prompt:"
echo "  05-stage-3-codex/prompts/refinement-prompt.md"
echo ""
echo "Codex will create optimized version in:"
echo "  05-stage-3-codex/output/"
echo ""
echo "(Stage 3 is optional - you can skip to Stage 4 if needed)"
read -p "Press Enter when Stage 3 is complete (or to skip)..."

echo ""
echo "👉 STAGE 4: Manual Final Review"
echo ""
echo "Review the workflow yourself:"
echo "  - Check 03-stage-2-claude-code/output/${WORKFLOW_NAME}.json"
echo "  - Verify test payloads make sense"
echo "  - Ensure it matches requirements"
echo ""
read -p "Press Enter when review is complete..."

echo ""
echo "=========================================="
echo "✅ PIPELINE COMPLETE"
echo "=========================================="
echo ""
echo "Your workflow is ready to import to n8n:"
echo "  03-stage-2-claude-code/output/${WORKFLOW_NAME}.json"
echo ""
echo "Test payloads available at:"
echo "  03-stage-2-claude-code/output/${WORKFLOW_NAME}-test-payloads.json"
echo ""
echo "Next steps:"
echo "1. Import to n8n"
echo "2. Set up environment variables"
echo "3. Test with provided payloads"
echo "4. Deploy to production"
echo ""
