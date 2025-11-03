# Multi-AI Workflow Validation Pipeline

A system that processes n8n workflow descriptions through multiple AI stages with validation gates, ensuring only production-ready workflows make it through.

## The Pipeline

```
Your Description
    ↓
Claude Desktop (Architecture)
    ↓
Gate 1: Spec Validation
    ↓
Claude Code (Implementation)
    ↓
Gate 2: Structure & Security
    ↓
Codex (Optimization) [Optional]
    ↓
Gate 3: Quality & Performance [Optional]
    ↓
Copilot (Final Review) [Optional]
    ↓
Gate 4: Integration Test [Optional]
    ↓
READY FOR n8n ✅
```

## Quick Start

### 1. Create Workflow Request
```bash
# Copy template
cp 00-input/templates/workflow-request.md \
   00-input/pending/my-workflow.md

# Fill out ALL sections in my-workflow.md
# Use the example as reference: 00-input/examples/example-lead-capture.md
```

### 2. Run Pipeline
```bash
chmod +x pipeline-control/run-pipeline.sh
./pipeline-control/run-pipeline.sh my-workflow
```

The script will guide you through each stage.

### 3. Import to n8n
```bash
# Your workflow will be at:
# 03-stage-2-claude-code/output/my-workflow.json

# Import it to n8n via the UI or API
```

## What Each Stage Does

**Stage 1: Claude Desktop (Architecture)**
- You provide: Business requirements in a filled-out template
- Claude Desktop creates: Complete technical architecture document
- Output: Detailed specification of every node, connection, and data flow

**Gate 1: Specification Validation**
- Automated checks: Architecture has all 12 required sections
- Validates: Node specifications, error handling, security considerations
- Result: PASS (continue) or FAIL (fix and retry)

**Stage 2: Claude Code (Implementation)**
- Input: Architecture from Stage 1
- Claude Code creates: Actual n8n workflow JSON
- Output: Working workflow + test payloads + implementation notes

**Gate 2: Structure & Security**
- Automated checks: Valid JSON, no hardcoded credentials, proper structure
- Validates: Connections, error handling, security
- Result: PASS (continue) or FAIL (fix and retry)

**Stages 3 & 4 (Optional)**
- Stage 3: Codex optimizes the code
- Stage 4: Copilot does final review
- These can be skipped for simpler workflows

## Core Features

✅ **Guided Process**: Step-by-step workflow creation
✅ **Automated Validation**: Catch errors before deployment
✅ **Multiple AI Review**: Each AI checks the previous one's work
✅ **Complete Documentation**: Auto-generated for every workflow
✅ **Test Payloads**: Ready-to-use test data included
✅ **Security First**: No hardcoded credentials allowed

## Directory Structure

```
00-input/           - Your workflow requests (fill out templates)
01-stage-1/         - Claude Desktop architecture output
02-gate-1/          - Automated spec validation
03-stage-2/         - Claude Code implementation output
04-gate-2/          - Automated structure/security checks
05-stage-3/         - Codex optimization (optional)
06-gate-3/          - Quality checks (optional)
07-stage-4/         - Copilot review (optional)
08-gate-4/          - Integration tests (optional)
09-approved/        - Production-ready workflows (optional)
pipeline-control/   - Pipeline management scripts
config/             - Configuration and schemas
docs/               - Documentation
tools/              - Utility scripts
```

## Minimal Workflow (Stages 1-2 Only)

For simple workflows, you can use just Stages 1-2:

1. **Fill out template** → `00-input/pending/my-workflow.md`
2. **Claude Desktop** → Creates architecture
3. **Gate 1** → Validates architecture
4. **Claude Code** → Builds workflow
5. **Gate 2** → Validates structure
6. **Import to n8n** → Done!

Total time: ~1-2 hours
Result: Production-ready workflow

## Full Pipeline (All 4 Stages)

For complex/critical workflows:

1. Stage 1: Claude Desktop (Architecture)
2. Gate 1: Spec validation
3. Stage 2: Claude Code (Implementation)
4. Gate 2: Structure validation
5. Stage 3: Codex (Optimization)
6. Gate 3: Quality validation
7. Stage 4: Copilot (Review)
8. Gate 4: Integration test
9. Move to approved/
10. Import to n8n

Total time: ~3-4 hours
Result: Reviewed, optimized, tested workflow

## Commands

```bash
# Start pipeline
./pipeline-control/run-pipeline.sh [workflow-name]

# Run individual gates
./02-gate-1-spec-validation/run-gate-1.sh [workflow-name]
./04-gate-2-structure-security/run-gate-2.sh [workflow-name]

# Check status (if tracking implemented)
./pipeline-control/show-status.sh

# Show errors (if tracking implemented)
./pipeline-control/show-errors.sh [workflow-name]
```

## For Your Business

This pipeline helps you build reliable n8n workflows for:
- Lead capture and qualification
- Vapi receptionist systems
- CRM integrations
- Appointment scheduling
- Email/SMS automation
- Google Maps scraping
- Client workflow automation

Each workflow is:
- Architected by Claude Desktop
- Implemented by Claude Code
- Validated automatically
- Documented completely
- Tested before deployment

## Example Workflow Included

See `00-input/examples/example-lead-capture.md` for a complete example of:
- How to fill out the template
- Level of detail required
- What good requirements look like

## Getting Help

- **Quick Start Guide**: See [QUICK-START.md](QUICK-START.md)
- **Stage 1 Instructions**: See `01-stage-1-claude-desktop/README.md`
- **Stage 2 Instructions**: See `03-stage-2-claude-code/README.md`
- **Troubleshooting**: Check gate reports in `02-gate-1/reports/` or `04-gate-2/reports/`

## Why This Works

**Traditional Approach Problems:**
- ❌ Requirements unclear → wrong workflow built
- ❌ No validation → errors found in production
- ❌ No documentation → hard to maintain
- ❌ No tests → breaks unexpectedly

**Multi-AI Pipeline Benefits:**
- ✅ Requirements validated before building
- ✅ Automatic error detection at each stage
- ✅ Complete documentation auto-generated
- ✅ Test cases created automatically
- ✅ Multiple AI reviews catch issues early

## License

Built for CoreReceptionAI workflow automation.

---

**Ready to build your first workflow?**

```bash
# 1. Copy the template
cp 00-input/templates/workflow-request.md 00-input/pending/my-first-workflow.md

# 2. Fill it out (use example as guide)
nano 00-input/pending/my-first-workflow.md

# 3. Run the pipeline
./pipeline-control/run-pipeline.sh my-first-workflow
```

The pipeline will guide you through each step!
