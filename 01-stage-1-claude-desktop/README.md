# Stage 1: Claude Desktop (Architecture & Design)

## Purpose
Transform the workflow request into a complete technical specification and architecture document that Claude Code can implement.

## Your Role (Claude Desktop)
You are the **architect**. You don't write code yet - you design the system, make architectural decisions, and create a blueprint that others will follow.

## Inputs
- Workflow request from `00-input/pending/[workflow-name].md`
- n8n schema from `config/n8n-schema.json`
- Validation rules from `config/validation-rules.json`

## Process

### Step 1: Read Everything
```bash
# Read the workflow request
cat 00-input/pending/[workflow-name].md

# Read n8n capabilities
cat config/n8n-schema.json

# Understand validation requirements
cat config/validation-rules.json

# Check for similar workflows (learn from past)
ls 09-approved/
```

### Step 2: Clarify Requirements
**If ANYTHING is unclear or missing, create a questions file BEFORE proceeding.**

Create `01-stage-1-claude-desktop/output/[workflow-name]-questions.md`:
```markdown
# Questions for User

Before I can create the architecture, I need clarification on:

## Critical Questions (Must answer)
1. [Question about missing requirement]
2. [Question about ambiguous logic]

## Optional Questions (Would help)
1. [Question about preferred approach]
2. [Question about edge case handling]
```

**STOP HERE until user answers questions.**

### Step 3: Create Architecture Document
Create `01-stage-1-claude-desktop/output/[workflow-name]-architecture.md`

**Required Sections**:

#### 1. Executive Summary
[2-3 sentences explaining what this does and why]

#### 2. System Overview
```
[ASCII diagram of data flow]

Example:
Website Form
    ↓
Webhook POST
    ↓
Validation
    ↓ [valid]       ↓ [invalid]
Process         Return Error
    ↓
Google Sheets Backup
    ↓
CRM Integration
    ↓
Success Response
```

#### 3. n8n Node Architecture
**List every node needed:**

| Node # | Node Type | Node Name | Purpose | Inputs | Outputs |
|--------|-----------|-----------|---------|--------|---------|
| 1 | Webhook | Receive Lead | Entry point | HTTP POST | JSON body |
| 2 | IF | Validate Required | Check fields | JSON | True/False |
| ... | ... | ... | ... | ... | ... |

#### 4. Data Flow Specification
**For each node, specify exact data transformations:**

**Node 1: Receive Lead**
- Input: `{ "name": "...", "phone": "..." }`
- Transformation: None
- Output: Same as input

**Node 2: Validate Required**
- Input: Previous output
- Transformation: Check `name` and `phone` exist
- Output: Boolean + original data

[Continue for ALL nodes...]

#### 5. Connection Map
**Specify all connections between nodes:**
```
Node 1 (Webhook) → Node 2 (Validate)
Node 2 (Validate) →  [true]  → Node 3 (Enrich)
Node 2 (Validate) →  [false] → Node 10 (Error Response)
Node 3 (Enrich) → Node 4 (Google Sheets)
...
```

#### 6. Error Handling Strategy
**For each potential failure:**

| Failure Point | Detection | Handling | User Impact |
|--------------|-----------|----------|-------------|
| Webhook timeout | No response in 30s | Return 408 error | User retries |
| Google Sheets API down | API error | Log locally, continue | Data backed up later |
| ... | ... | ... | ... |

#### 7. Security Architecture
- **Credential Management**: [Where/how stored]
- **Data Encryption**: [What's encrypted, how]
- **Input Validation**: [What's validated, how]
- **Rate Limiting**: [How implemented]
- **Audit Logging**: [What's logged, where]

#### 8. Performance Considerations
- **Bottlenecks**: [Identified slow points]
- **Optimization Strategy**: [How to handle them]
- **Scaling Plan**: [What if volume increases]

#### 9. Environment Variables Needed
```bash
# List ALL environment variables required
VARIABLE_NAME=description_of_what_it_is
ANOTHER_VAR=description
```

#### 10. Test Strategy
For each test case from the request, specify:
- Test data
- Which nodes are exercised
- Expected node outputs
- How to verify success

#### 11. Assumptions & Constraints
Document what you're assuming:
- [Assumption 1]
- [Assumption 2]

Known limitations:
- [Limitation 1]
- [Limitation 2]

#### 12. Alternative Approaches Considered
For major design decisions, document alternatives:

**Decision**: Use Google Sheets for backup
**Alternatives Considered**:
- PostgreSQL database (rejected: requires additional infrastructure)
- Local file storage (rejected: not accessible across instances)
**Rationale**: Google Sheets provides simple, accessible backup with no setup

### Step 4: Create Implementation Guide
Create `01-stage-1-claude-desktop/output/[workflow-name]-implementation-guide.md`

This tells Claude Code exactly how to build each node:

```markdown
# Implementation Guide for [Workflow Name]

## Node 1: Webhook Trigger
**n8n Node Type**: `n8n-nodes-base.webhook`
**Configuration**:
```json
{
  "parameters": {
    "httpMethod": "POST",
    "path": "roofing-lead",
    "responseMode": "responseNode"
  },
  "position": [250, 300]
}
```
**Why these settings**: [Explanation]

## Node 2: Validate Required Fields
**n8n Node Type**: `n8n-nodes-base.if`
**Configuration**:
[Exact configuration...]
**Why**: [Explanation]

[Continue for ALL nodes...]
```

### Step 5: Create Test Specifications
Create `01-stage-1-claude-desktop/output/[workflow-name]-test-specs.md`

For each test case, provide:
- Exact test payload JSON
- Expected behavior at each node
- Expected final output
- How to verify success

### Step 6: Self-Review Checklist
Before submitting to Gate 1, verify:

- [ ] Architecture document is complete (all 12 sections)
- [ ] Every node is specified in detail
- [ ] All connections are documented
- [ ] Error handling is comprehensive
- [ ] Security requirements are addressed
- [ ] Performance considerations noted
- [ ] Test strategy is clear
- [ ] Implementation guide is detailed enough for Claude Code
- [ ] No ambiguities remain (or questions.md created)

## Outputs
Create in `01-stage-1-claude-desktop/output/`:

1. **[workflow-name]-architecture.md** (Required)
2. **[workflow-name]-implementation-guide.md** (Required)
3. **[workflow-name]-test-specs.md** (Required)
4. **[workflow-name]-questions.md** (If anything unclear)
5. **[workflow-name]-decisions.md** (Design decision log)

## Success Criteria
- [ ] Complete architecture document
- [ ] Detailed implementation guide
- [ ] Comprehensive test specifications
- [ ] All questions answered or flagged
- [ ] Ready for Gate 1 validation

## Common Mistakes to Avoid
1. ❌ Leaving requirements ambiguous
2. ❌ Not documenting WHY decisions were made
3. ❌ Skipping error handling design
4. ❌ Incomplete node specifications
5. ❌ Missing security considerations
6. ❌ No alternative approaches documented
7. ❌ Test cases not detailed enough

## Handoff to Gate 1
Once complete, run:
```bash
./02-gate-1-spec-validation/run-gate-1.sh [workflow-name]
```

Gate 1 will validate your architecture is complete before passing to Claude Code.
