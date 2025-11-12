# Quick Start: Your First Workflow in 2 Hours

Build your first production-ready n8n workflow using the multi-AI pipeline.

## Prerequisites

- Claude Desktop (for Stage 1 - Architecture)
- Claude Code (for Stage 2 - Implementation)
- Text editor
- Bash/Git Bash (for running scripts)

## Step 1: Create Your Request (15 minutes)

```bash
# Navigate to the pipeline directory
cd workflow-pipeline

# Copy the template
cp 00-input/templates/workflow-request.md \
   00-input/pending/lead-capture.md

# Open and edit
nano 00-input/pending/lead-capture.md
# Or use your preferred editor
```

**Fill out every section.** Use the example as reference:
```bash
cat 00-input/examples/example-lead-capture.md
```

**Critical sections to complete:**
- Workflow Name
- Business Context (what/who/why)
- Trigger Information
- Processing Logic (step-by-step)
- Expected Output
- Error Handling
- Test Cases

**Don't skip anything** - incomplete requests fail Gate 1.

## Step 2: Stage 1 - Claude Desktop Architecture (30 minutes)

Open **Claude Desktop** and give it this prompt:

```
I need you to architect an n8n workflow.

Please read these files:
1. workflow-pipeline/00-input/pending/lead-capture.md
2. workflow-pipeline/01-stage-1-claude-desktop/README.md
3. workflow-pipeline/01-stage-1-claude-desktop/prompts/architecture-prompt.md

Then create the complete architecture documents as specified in the README.

Output files to: workflow-pipeline/01-stage-1-claude-desktop/output/
```

**What Claude Desktop will create:**
- `lead-capture-architecture.md` (complete technical spec)
- `lead-capture-implementation-guide.md` (how to build each node)
- `lead-capture-test-specs.md` (test cases)

**Wait for Claude Desktop to finish** before proceeding.

## Step 3: Gate 1 - Validate Architecture (2 minutes)

```bash
# Run Gate 1 validation
./02-gate-1-spec-validation/run-gate-1.sh lead-capture
```

**If it passes:** ✅ Continue to Step 4
**If it fails:** ❌ Read the report, fix errors in Stage 1 output, re-run Gate 1

**Common failures:**
- Missing architecture sections
- Incomplete node specifications
- No error handling documented

**Fix and retry until Gate 1 passes.**

## Step 4: Stage 2 - Claude Code Implementation (40 minutes)

Open **Claude Code** and give it this prompt:

```
Build an n8n workflow based on the architecture specification.

Please read:
1. workflow-pipeline/01-stage-1-claude-desktop/output/lead-capture-architecture.md
2. workflow-pipeline/01-stage-1-claude-desktop/output/lead-capture-implementation-guide.md
3. workflow-pipeline/01-stage-1-claude-desktop/output/lead-capture-test-specs.md
4. workflow-pipeline/03-stage-2-claude-code/README.md
5. workflow-pipeline/03-stage-2-claude-code/prompts/implementation-prompt.md

Then implement the workflow as specified.

IMPORTANT: Build incrementally (3-5 nodes at a time) and validate each increment.

Output files to: workflow-pipeline/03-stage-2-claude-code/output/
```

**What Claude Code will create:**
- `lead-capture.json` (the actual n8n workflow)
- `lead-capture-test-payloads.json` (test data)
- `lead-capture-implementation-notes.md` (documentation)

**Wait for Claude Code to finish** before proceeding.

## Step 5: Gate 2 - Validate Structure & Security (2 minutes)

```bash
# Run Gate 2 validation
./04-gate-2-structure-security/run-gate-2.sh lead-capture
```

**If it passes:** ✅ Your workflow is ready!
**If it fails:** ❌ Fix errors in Stage 2 output, re-run Gate 2

**Common failures:**
- Invalid JSON syntax
- Hardcoded credentials (must use env variables)
- Missing required files

**Fix and retry until Gate 2 passes.**

## Step 6: Import to n8n (10 minutes)

### Option A: Via n8n UI
1. Open n8n
2. Click "Import workflow"
3. Select `03-stage-2-claude-code/output/lead-capture.json`
4. Click "Import"

### Option B: Via API
```bash
curl -X POST http://localhost:5678/api/v1/workflows/import \
  -H "Content-Type: application/json" \
  -d @03-stage-2-claude-code/output/lead-capture.json
```

## Step 7: Configure Environment Variables (5 minutes)

Check the implementation notes for required env variables:
```bash
cat 03-stage-2-claude-code/output/lead-capture-implementation-notes.md
```

Add them to your n8n environment or `.env` file:
```bash
# Example
HUBSPOT_API_KEY=your_key_here
SLACK_WEBHOOK_URL=your_webhook_here
TWILIO_ACCOUNT_SID=your_sid_here
# ... etc
```

## Step 8: Test the Workflow (10 minutes)

Use the provided test payloads:
```bash
cat 03-stage-2-claude-code/output/lead-capture-test-payloads.json
```

**Test Case 1: Happy Path**
1. Trigger the workflow with test payload
2. Verify expected behavior
3. Check all integrations worked

**Test Case 2: Error Cases**
1. Try with missing fields
2. Verify error handling works
3. Check error messages are clear

## Step 9: Deploy to Production (5 minutes)

Once all tests pass:

1. **Activate the workflow** in n8n
2. **Update webhook URLs** in your forms/integrations
3. **Monitor initial executions** to ensure it works
4. **Set up alerts** for failures

## Done! 🎉

**Total time**: ~2 hours
**What you have**:
- ✅ Production-ready n8n workflow
- ✅ Complete documentation
- ✅ Test cases for validation
- ✅ Architecture specification for future reference
- ✅ Implementation notes for troubleshooting

## Optional: Advanced Pipeline (Stages 3-4)

For complex workflows, add optimization and review:

### Stage 3: Codex Optimization
```
Use Codex to optimize:
- Read: 03-stage-2-claude-code/output/lead-capture.json
- Read: 05-stage-3-codex/README.md
- Create optimization report and improved version
```

### Stage 4: Copilot Final Review
```
Use Copilot for final review:
- Read all previous outputs
- Read: 07-stage-4-copilot/README.md
- Create final review and approve for production
```

## Automated Pipeline Option

Instead of manual steps, run the entire pipeline:
```bash
./pipeline-control/run-pipeline.sh lead-capture
```

This will guide you through all stages interactively.

## Troubleshooting

### Gate 1 Fails
**Problem**: Missing architecture sections
**Fix**: Check `02-gate-1-spec-validation/reports/lead-capture-gate-1-report.md`
**Action**: Complete missing sections, re-run Gate 1

### Gate 2 Fails
**Problem**: Invalid JSON or security issues
**Fix**: Check `04-gate-2-structure-security/reports/lead-capture-gate-2-report.md`
**Action**: Fix JSON errors, use env variables for credentials, re-run Gate 2

### Workflow Doesn't Import to n8n
**Problem**: n8n version mismatch or invalid node types
**Fix**: Check n8n error message
**Action**: Update node types in workflow JSON, verify n8n version compatibility

### Tests Fail in n8n
**Problem**: Environment variables not set or external APIs down
**Fix**: Check n8n execution logs
**Action**: Set all required env variables, verify API access

## Tips for Success

1. **Be Detailed**: The more detail in your request, the better the workflow
2. **Use Examples**: Reference `00-input/examples/example-lead-capture.md`
3. **Don't Skip Gates**: They catch errors early (saves time)
4. **Test Thoroughly**: Use all provided test cases
5. **Document Changes**: If you modify the workflow, update the docs

## Next Workflows

Now that you've built your first workflow, create more:

```bash
# Roofing CRM integration
cp 00-input/templates/workflow-request.md \
   00-input/pending/roofing-crm-sync.md

# Vapi receptionist webhook
cp 00-input/templates/workflow-request.md \
   00-input/pending/vapi-receptionist.md

# Google Maps scraper
cp 00-input/templates/workflow-request.md \
   00-input/pending/google-maps-scraper.md
```

Each workflow follows the same process:
1. Fill out template
2. Claude Desktop → architecture
3. Gate 1 → validate
4. Claude Code → implement
5. Gate 2 → validate
6. Import to n8n
7. Test & deploy

**Happy workflow building!** 🚀

## ⚡ New: Stage 3 Automatic Review (Added January 2025)

After Stage 2 completes, your workflow is automatically reviewed by Codex:

```bash
# Stage 2 complete - push to GitHub
git checkout -b workflow/my-workflow
git add 03-stage-2-claude-code/output/*
git commit -m "Stage 2: Implement workflow"
git push origin workflow/my-workflow

# Create PR - Codex reviews automatically
gh pr create --title "My Workflow"

# Wait 1-2 minutes for automatic Codex review
# Check PR for review comments
gh pr view --web

# Fix any P0 issues found
# Push fixes - Codex re-reviews automatically
git add .
git commit -m "Fix: Apply Codex suggestions"
git push

# Merge when no P0 issues
gh pr merge --squash
```

**Codex automatically checks for:**
- ❌ Missing error handling
- ❌ Hardcoded credentials
- ❌ Unsafe webhook configurations
- ❌ HIPAA violations (patient data in logs)
- ⚠️ Missing validation and timeouts
- 💡 Performance optimizations

**Setup**: See `05-stage-3-codex/README.md` for 5-minute setup guide

