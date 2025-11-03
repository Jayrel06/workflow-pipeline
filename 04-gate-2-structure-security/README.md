# Gate 2: Structure & Security Validation

## Purpose
Validate that Stage 2 (Claude Code) produced valid, secure n8n workflow JSON.

## What This Gate Checks

### 1. JSON Structure Validation
- Valid JSON syntax
- Required fields present (name, nodes, connections)
- Nodes array structure
- No duplicate node IDs
- Valid position coordinates

### 2. Security Scan
- No hardcoded API keys
- No hardcoded passwords/secrets
- No credentials in URLs
- Environment variables used properly
- No sensitive data in node names

### 3. Connection Validation
- All source nodes exist
- All target nodes exist
- No orphaned nodes
- Connection structure valid
- No broken references

### 4. Node Configuration
- All required node fields present
- Error handling configured
- Credentials use n8n system
- No disabled nodes (unless intentional)

## How to Run

```bash
./04-gate-2-structure-security/run-gate-2.sh [workflow-name]
```

## Validators

### json-structure.js
Validates JSON syntax and n8n structure requirements.

**Checks**:
- Valid JSON
- Required top-level fields
- Nodes array format
- Duplicate IDs
- Position coordinates

### security-scanner.js
Scans for security vulnerabilities.

**Checks**:
- Hardcoded API keys (OpenAI, Slack, GitHub, Google)
- Hardcoded passwords/tokens
- Credentials in URLs
- Environment variable usage
- Sensitive data exposure

### Connection validation
Built into run-gate-2.sh script.

**Checks**:
- Source/target nodes exist
- Connection structure valid
- No orphaned nodes
- Proper connection format

## Pass Criteria

**PASS** if:
- All validators return 0 errors
- Warnings are acceptable
- JSON is valid
- No security issues

**FAIL** if:
- Any CRITICAL errors found
- Hardcoded credentials detected
- Invalid JSON structure
- Broken connections

## Common Failures

### Hardcoded Credentials
**Problem**: API keys in parameters
**Fix**: Use `={{$env.API_KEY}}` instead

### Missing Required Fields
**Problem**: Node missing id, name, type, etc.
**Fix**: Add all required fields to node

### Invalid Connections
**Problem**: Connection references non-existent node
**Fix**: Verify all node IDs in connections exist

### Duplicate Node IDs
**Problem**: Two nodes have same ID
**Fix**: Ensure each node has unique ID

## Output

Creates report: `04-gate-2-structure-security/reports/[workflow-name]-gate-2-report.md`

## Next Step

If Gate 2 passes:
```bash
cd 05-stage-3-codex
# Use GitHub Copilot or Codex to optimize
```
