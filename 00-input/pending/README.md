# Pending Workflow Requests

This directory contains workflow requests waiting to be processed through the pipeline.

## How to Submit a Workflow

### 1. Copy the Template
```bash
cp ../templates/workflow-request.md ./your-workflow-name.md
```

### 2. Fill Out ALL Sections
Open `your-workflow-name.md` and complete every section. Use the checklist:
```bash
cat ../templates/requirements-checklist.md
```

### 3. Validate Your Request (Optional but Recommended)
```bash
../../tools/validate-request.sh your-workflow-name.md
```

### 4. Start the Pipeline
```bash
cd ../..
./pipeline-control/run-pipeline.sh your-workflow-name
```

## Example Workflows
See `../examples/` for complete example workflow requests.

## File Naming Convention
- Use lowercase
- Use hyphens for spaces
- Be descriptive
- Example: `roofing-lead-capture.md`, `vapi-receptionist-webhook.md`

## What Happens Next
Once you run the pipeline:

1. **Stage 1**: Claude Desktop creates architecture
2. **Gate 1**: Automated validation checks completeness
3. **Stage 2**: Claude Code builds the workflow
4. **Gate 2**: Structure and security validation
5. **Stage 3**: Codex optimizes the code
6. **Gate 3**: Quality and performance checks
7. **Stage 4**: Copilot final review
8. **Gate 4**: Integration testing
9. **Approval**: Moved to `09-approved/`

## Need Help?
- See: `../../docs/PIPELINE-OVERVIEW.md`
- Quick Start: `../../QUICK-START.md`
- Examples: `../examples/`

## Status Tracking
Check status of your workflow:
```bash
../../pipeline-control/show-status.sh
```

View any errors:
```bash
../../pipeline-control/show-errors.sh your-workflow-name
```
