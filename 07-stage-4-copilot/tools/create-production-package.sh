#!/bin/bash
# Creates production deployment package

WORKFLOW_NAME=$1

if [ -z "$WORKFLOW_NAME" ]; then
    echo "Usage: ./create-production-package.sh [workflow-name]"
    exit 1
fi

echo "📦 Creating production package for: $WORKFLOW_NAME"
echo ""

PACKAGE_DIR="07-stage-4-copilot/output/${WORKFLOW_NAME}-production-package"

# Create package directory
mkdir -p "$PACKAGE_DIR"

# Determine which workflow version to use
FINAL_JSON="07-stage-4-copilot/output/${WORKFLOW_NAME}-final.json"
if [ ! -f "$FINAL_JSON" ]; then
    # Try optimized version
    if [ -f "05-stage-3-codex/output/${WORKFLOW_NAME}-optimized.json" ]; then
        FINAL_JSON="05-stage-3-codex/output/${WORKFLOW_NAME}-optimized.json"
    else
        FINAL_JSON="03-stage-2-claude-code/output/${WORKFLOW_NAME}.json"
    fi
fi

if [ ! -f "$FINAL_JSON" ]; then
    echo "❌ Error: No workflow file found"
    exit 1
fi

# Copy workflow
cp "$FINAL_JSON" "$PACKAGE_DIR/workflow.json"
echo "✓ Copied workflow.json"

# Copy test payloads
TEST_PAYLOADS="03-stage-2-claude-code/output/${WORKFLOW_NAME}-test-payloads.json"
if [ -f "$TEST_PAYLOADS" ]; then
    cp "$TEST_PAYLOADS" "$PACKAGE_DIR/test-payloads.json"
    echo "✓ Copied test-payloads.json"
fi

# Create README.md
cat > "$PACKAGE_DIR/README.md" << EOF
# ${WORKFLOW_NAME} - Production Workflow

This workflow has passed all validation gates and is approved for production.

## Validation Status

✅ Stage 1: Claude Desktop (Architecture)
✅ Gate 1: Specification validated
✅ Stage 2: Claude Code (Implementation)
✅ Gate 2: Structure & security validated
✅ Stage 3: Codex/Copilot (Optimization)
✅ Gate 3: Quality & performance validated
✅ Stage 4: GitHub Copilot (Final review)
✅ Gate 4: Integration tested

## Quick Start

1. Import to n8n
2. Configure environment variables
3. Test with test-payloads.json
4. Activate workflow

## Files Included

- \`workflow.json\` - The n8n workflow
- \`test-payloads.json\` - Test data
- \`DEPLOYMENT.md\` - Deployment instructions
- \`TESTING.md\` - How to test
- \`TROUBLESHOOTING.md\` - Common issues

## Support

For issues, refer to validation reports in the pipeline repository.
EOF

echo "✓ Created README.md"

# Create DEPLOYMENT.md
cat > "$PACKAGE_DIR/DEPLOYMENT.md" << 'EOF'
# Deployment Instructions

## Prerequisites

- n8n instance running
- Access to n8n admin interface
- Environment variables configured

## Step 1: Import Workflow

### Via n8n UI:
1. Open n8n
2. Settings > Import Workflow
3. Upload `workflow.json`

### Via API:
```bash
curl -X POST http://localhost:5678/api/v1/workflows/import \
  -H "Content-Type: application/json" \
  -d @workflow.json
```

## Step 2: Configure Environment Variables

Check the workflow for required environment variables.

In n8n:
1. Settings > Variables
2. Add each required variable
3. Save

## Step 3: Test

1. Use test payloads from `test-payloads.json`
2. Run each test case
3. Verify expected outputs
4. Check error handling

## Step 4: Activate

1. Verify all tests pass
2. Enable workflow
3. Monitor initial executions

## Rollback Plan

If issues occur:
1. Deactivate workflow immediately
2. Review execution logs
3. Identify issue
4. Fix and re-deploy

## Monitoring

Monitor:
- Execution success rate
- Error logs
- Response times
- API rate limits
EOF

echo "✓ Created DEPLOYMENT.md"

# Create TESTING.md
cat > "$PACKAGE_DIR/TESTING.md" << 'EOF'
# Testing Instructions

## Test Payloads

Test payloads are provided in `test-payloads.json`.

## How to Test

### Test 1: Happy Path
1. Use the "Happy Path" payload
2. Trigger workflow
3. Verify expected output
4. Check all integrations worked

### Test 2: Error Cases
1. Use error scenario payloads
2. Verify error handling
3. Check error messages
4. Ensure graceful failure

### Test 3: Edge Cases
1. Test with unusual inputs
2. Verify validation works
3. Check boundary conditions

## Manual Testing

1. Import workflow to test instance
2. Configure environment variables
3. Run each test case
4. Document results
5. Fix any issues found

## Production Testing

After deployment:
1. Monitor first 10 executions
2. Check logs for errors
3. Verify integrations
4. Confirm expected behavior
EOF

echo "✓ Created TESTING.md"

# Create TROUBLESHOOTING.md
cat > "$PACKAGE_DIR/TROUBLESHOOTING.md" << 'EOF'
# Troubleshooting Guide

## Common Issues

### Workflow Won't Import
**Problem**: Import fails
**Solution**:
- Check n8n version compatibility
- Verify JSON syntax
- Check node types exist in your n8n

### Environment Variables Not Found
**Problem**: Workflow errors on missing vars
**Solution**:
- Check Settings > Variables in n8n
- Verify variable names match exactly
- Restart n8n after adding variables

### API Calls Failing
**Problem**: External API calls fail
**Solution**:
- Verify API credentials
- Check API rate limits
- Test API outside n8n
- Review error messages

### Workflow Timeouts
**Problem**: Executions timeout
**Solution**:
- Check n8n execution timeout settings
- Optimize slow nodes
- Add pagination for large datasets
- Consider async execution

## Getting Help

1. Check n8n execution logs
2. Review validation reports
3. Check node documentation
4. Search n8n community forum

## Debug Mode

Enable debug logging:
1. n8n settings > Debug mode
2. Re-run workflow
3. Check detailed logs
4. Identify issue
EOF

echo "✓ Created TROUBLESHOOTING.md"

echo ""
echo "=========================================="
echo "✅ Production package created!"
echo "=========================================="
echo ""
echo "Package location:"
echo "  $PACKAGE_DIR"
echo ""
echo "Files created:"
echo "  - workflow.json"
echo "  - test-payloads.json"
echo "  - README.md"
echo "  - DEPLOYMENT.md"
echo "  - TESTING.md"
echo "  - TROUBLESHOOTING.md"
echo ""
echo "Next: Run Gate 4 to validate deployment package"
echo "  ./08-gate-4-integration-test/run-gate-4.sh $WORKFLOW_NAME"
