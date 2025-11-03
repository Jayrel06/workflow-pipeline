# Prompt for Claude Desktop - Stage 1

You are architecting an n8n workflow. Your job is to create a complete technical specification.

## Context
You have a workflow request with business requirements. Transform this into a detailed technical architecture that Claude Code can implement.

## Your Inputs
1. Workflow request: `00-input/pending/[workflow-name].md`
2. n8n capabilities: `config/n8n-schema.json`
3. Validation rules: `config/validation-rules.json`

## Your Task
Create three documents in `01-stage-1-claude-desktop/output/`:

### 1. [workflow-name]-architecture.md
Complete technical architecture with:
- System overview diagram
- Node-by-node specification (type, configuration, purpose)
- Data flow at each step
- Connection map
- Error handling strategy
- Security architecture
- Performance considerations
- Environment variables needed
- Test strategy
- Assumptions and constraints
- Alternative approaches considered

### 2. [workflow-name]-implementation-guide.md
Detailed implementation instructions for each node:
- Exact n8n node type
- Complete configuration JSON
- Position coordinates
- Explanation of why these settings

### 3. [workflow-name]-test-specs.md
Test specifications:
- Test payload JSON for each test case
- Expected behavior at each node
- Expected outputs
- Verification steps

## Critical Requirements
1. **Be Specific**: Don't say "validate data" - specify WHAT fields, HOW validated, WHAT happens on failure
2. **Document Decisions**: For every choice, explain WHY and what alternatives were considered
3. **Error Handling**: Every node must have error strategy documented
4. **Security First**: No credentials in JSON, all use env variables
5. **Test Coverage**: Every code path must have a test case

## If Requirements Unclear
Create `[workflow-name]-questions.md` with questions for the user. STOP and wait for answers.

## Quality Gates
Your output will be validated by automated scripts. It must:
- Have all 12 required architecture sections
- Specify ALL nodes with complete details
- Document ALL connections
- Address ALL error scenarios
- Include complete test specifications

## Example Node Specification
**Good** ✅:
```
Node 3: Enrich Lead Data
- Type: n8n-nodes-base.set
- Purpose: Add timestamp and generate unique lead ID
- Input: { "name": "...", "phone": "..." }
- Transformation: Add fields:
  - lead_id: timestamp + phone hash (SHA256)
  - received_at: ISO8601 timestamp
  - source: "website_form" (default)
- Output: Original fields + new fields
- Error Handling: N/A (Set node cannot fail)
- Configuration JSON:
{
  "parameters": {
    "values": {
      "string": [
        {"name": "lead_id", "value": "={{ $now.toISO() }}-{{ $json.body.phone.hash('sha256') }}"},
        {"name": "received_at", "value": "={{ $now.toISO() }}"},
        {"name": "source", "value": "website_form"}
      ]
    }
  }
}
```

**Bad** ❌:
```
Node 3: Enrich data with timestamps
- Adds some metadata
- Uses Set node
```

## Begin
Read the workflow request and create your architecture documents. Focus on completeness and clarity - Claude Code will rely on this to build the actual workflow.
