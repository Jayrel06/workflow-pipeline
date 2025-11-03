# Prompt for Claude Code - Stage 2

You are implementing an n8n workflow based on a complete architecture specification.

## Context
Stage 1 (Claude Desktop) has created a detailed architecture. Your job is to build the actual n8n workflow JSON that implements this design.

## Your Inputs
1. Architecture: `01-stage-1-claude-desktop/output/[workflow-name]-architecture.md`
2. Implementation Guide: `01-stage-1-claude-desktop/output/[workflow-name]-implementation-guide.md`
3. Test Specs: `01-stage-1-claude-desktop/output/[workflow-name]-test-specs.md`
4. n8n Schema: `config/n8n-schema.json`

## Your Task
Create in `03-stage-2-claude-code/output/`:

### 1. [workflow-name].json
The complete n8n workflow implementing the architecture.

**Build incrementally**:
- Start with trigger + first 3 nodes
- Validate with `./tools/validate-json.sh` (if available)
- Add next 3-5 nodes
- Validate again
- Repeat until complete

### 2. [workflow-name]-test-payloads.json
Test data for each test case from test specs.

### 3. [workflow-name]-implementation-notes.md
Document your implementation process, any deviations, challenges.

## Critical Requirements
1. **Follow the Spec**: Implement exactly what the architecture specifies
2. **Build Incrementally**: 3-5 nodes at a time, validate each increment
3. **No Hardcoded Credentials**: Use `={{$env.VARIABLE_NAME}}`
4. **Error Handling**: Add per architecture specification
5. **Test Everything**: Create test payloads for all test cases

## n8n JSON Structure
```json
{
  "name": "Workflow Name",
  "nodes": [
    {
      "id": "unique-id",
      "name": "Node Name",
      "type": "n8n-nodes-base.nodeType",
      "typeVersion": 1,
      "position": [x, y],
      "parameters": {
        // Node configuration
      }
    }
  ],
  "connections": {
    "source-node-id": {
      "main": [[{"node": "target-node-id", "type": "main", "index": 0}]]
    }
  },
  "settings": {}
}
```

## If Architecture is Unclear
DO NOT guess. Create `[workflow-name]-questions.md` and ask for clarification.

## Validation
After each increment (if validator exists):
```bash
./tools/validate-json.sh 03-stage-2-claude-code/output/[workflow-name].json
```

Fix errors immediately before adding more nodes.

## Quality Gates
Your output will be validated by Gate 2:
- JSON syntax must be valid
- All nodes must have required fields
- Connections must reference existing nodes
- No hardcoded credentials
- Error handling must match spec

## Begin
Read the architecture and implementation guide. Build the workflow incrementally, validating each step.
