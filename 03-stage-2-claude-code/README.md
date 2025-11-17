# Stage 2: Claude Code (Implementation)

## Purpose
Build the actual n8n workflow JSON based on the architecture from Stage 1.

## Your Role (Claude Code)
You are the **builder**. You take the complete specification from Claude Desktop and turn it into working n8n JSON.

## Inputs
From Stage 1:
- `01-stage-1-claude-desktop/output/[workflow-name]-architecture.md`
- `01-stage-1-claude-desktop/output/[workflow-name]-implementation-guide.md`
- `01-stage-1-claude-desktop/output/[workflow-name]-test-specs.md`

From config:
- `config/n8n-schema.json` (reference for valid n8n JSON structure)

## Process

### Step 0: Query Memory System First ⚡ **NEW**

**ALWAYS check the memory system BEFORE starting implementation!**

```bash
# Check for similar workflows
curl http://localhost:3001/api/patterns/search?q=webhook&limit=10

# Search for relevant patterns
curl http://localhost:3001/api/patterns/search?q=your-use-case&limit=10

# Find workflow templates
curl http://localhost:3001/api/prompts?category=workflow&limit=10

# Review past implementations
curl http://localhost:3001/api/github/activity?repo=workflow-pipeline&limit=20

# Get specific knowledge
curl http://localhost:3001/api/knowledge/search?q=authentication&limit=5
```

**Why?**
- ✅ Reuse proven patterns
- ✅ Avoid past mistakes
- ✅ Save time with templates
- ✅ Ensure consistency

See `MEMORY-SYSTEM.md` in repo root for full API documentation.

---

### Step 1: Read ALL Stage 1 Outputs
```bash
# Read the complete architecture
cat 01-stage-1-claude-desktop/output/[workflow-name]-architecture.md

# Read implementation guide
cat 01-stage-1-claude-desktop/output/[workflow-name]-implementation-guide.md

# Read test specifications
cat 01-stage-1-claude-desktop/output/[workflow-name]-test-specs.md

# Understand n8n schema
cat config/n8n-schema.json
```

**DO NOT PROCEED** until you fully understand what you're building.

### Step 2: Build Incrementally
**CRITICAL**: Build 3-5 nodes at a time, validate each increment.

#### Iteration 1: Core Trigger + First Logic
```bash
# Create initial workflow with first few nodes
# Save to: 03-stage-2-claude-code/output/[workflow-name]-v1.json

# Validate immediately
./tools/validate-json.sh 03-stage-2-claude-code/output/[workflow-name]-v1.json
```

If validation passes → Continue
If validation fails → Fix errors before adding more nodes

#### Iteration 2: Add Next 3-5 Nodes
```bash
# Add more nodes
# Save as: [workflow-name]-v2.json

# Validate again
./tools/validate-json.sh 03-stage-2-claude-code/output/[workflow-name]-v2.json
```

**Continue this cycle until complete.**

### Step 3: Implement According to Spec

**💡 TIP**: Before implementing each node type, check memory:
```bash
# Example: Before implementing HTTP Request node
curl http://localhost:3001/api/patterns/search?q=httpRequest+node&limit=5
```

For EACH node in the implementation guide:

1. **Create Node Object**:
```json
{
  "id": "unique-node-id",
  "name": "Descriptive Node Name",
  "type": "n8n-nodes-base.nodeType",
  "typeVersion": 1,
  "position": [x, y],
  "parameters": {
    // Exact configuration from implementation guide
  }
}
```

2. **Add Error Handling** (if specified in architecture):
```json
{
  "continueOnFail": true,
  "onError": "continueRegularOutput"
}
```

3. **Use Environment Variables** (never hardcode):
```json
{
  "parameters": {
    "value": "={{ $env.VARIABLE_NAME }}"
  }
}
```

### Step 4: Build Connections
Following the connection map from architecture:
```json
{
  "connections": {
    "source-node-id": {
      "main": [
        [
          {
            "node": "target-node-id",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  }
}
```

### Step 5: Create Test Payloads
Create `03-stage-2-claude-code/output/[workflow-name]-test-payloads.json`:
```json
{
  "test_cases": [
    {
      "name": "Happy Path",
      "description": "Normal operation with valid data",
      "payload": {
        // From test specs
      },
      "expected_outcome": "success",
      "expected_final_data": {
        // Expected output
      }
    }
  ]
}
```

### Step 6: Document Implementation
Create `03-stage-2-claude-code/output/[workflow-name]-implementation-notes.md`:
```markdown
# Implementation Notes: [Workflow Name]

## Build Process
- Started: [timestamp]
- Completed: [timestamp]
- Iterations: [number]

## Deviations from Architecture
[If you had to deviate from the spec, document why]

## Challenges Encountered
1. [Challenge 1]: [How resolved]

## Nodes Created
- Total Nodes: [count]
- Node Types Used: [list]

## Environment Variables Required
```bash
VAR_NAME=description
```

## Testing Notes
- [What was tested]
- [What passed/failed]

## Ready for Gate 2
- [ ] All nodes implemented per spec
- [ ] All connections created
- [ ] Error handling added
- [ ] No hardcoded credentials
- [ ] Test payloads created
- [ ] Documentation complete
```

### Step 7: Self-Review Checklist
Before submitting to Gate 2:

- [ ] Valid JSON (no syntax errors)
- [ ] All nodes from architecture implemented
- [ ] All connections match connection map
- [ ] Environment variables used (no hardcoded values)
- [ ] Error handling added per architecture
- [ ] Node positions are reasonable
- [ ] Test payloads created for all test cases
- [ ] Implementation notes documented

## Outputs
Create in `03-stage-2-claude-code/output/`:

1. **[workflow-name].json** (The actual workflow)
2. **[workflow-name]-test-payloads.json** (Test data)
3. **[workflow-name]-implementation-notes.md** (Documentation)

## Success Criteria
- [ ] Complete n8n workflow JSON
- [ ] Matches architecture specification
- [ ] Test payloads for all cases
- [ ] Documentation complete
- [ ] Ready for Gate 2 validation

## Common Mistakes to Avoid
1. ❌ Building entire workflow at once (build incrementally!)
2. ❌ Hardcoding credentials or API keys
3. ❌ Missing error handling
4. ❌ Invalid node connections
5. ❌ Deviating from architecture without documenting
6. ❌ No test payloads
7. ❌ Skipping validation until the end

## Handoff to Gate 2
Once complete, run:
```bash
./04-gate-2-structure-security/run-gate-2.sh [workflow-name]
```

Gate 2 will validate structure, security, and n8n compatibility.
