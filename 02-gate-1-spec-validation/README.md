# Gate 1: Specification Validation

## Purpose
Validate that Stage 1 (Claude Desktop) produced a complete, valid architecture specification before passing to Stage 2 (Claude Code).

## What This Gate Checks

### 1. File Existence
- [ ] `[workflow-name]-architecture.md` exists
- [ ] `[workflow-name]-implementation-guide.md` exists
- [ ] `[workflow-name]-test-specs.md` exists

### 2. Architecture Completeness (12 Required Sections)
- [ ] Executive Summary
- [ ] System Overview
- [ ] n8n Node Architecture
- [ ] Data Flow Specification
- [ ] Connection Map
- [ ] Error Handling Strategy
- [ ] Security Architecture
- [ ] Performance Considerations
- [ ] Environment Variables Needed
- [ ] Test Strategy
- [ ] Assumptions & Constraints
- [ ] Alternative Approaches Considered

### 3. Node Specifications Quality
- [ ] Every node has a type
- [ ] Every node has a purpose
- [ ] Every node has inputs/outputs
- [ ] No hardcoded credentials
- [ ] Error handling specified

### 4. Implementation Guide Quality
- [ ] Matches architecture nodes
- [ ] Has configuration JSON for each node
- [ ] Has position coordinates
- [ ] Has explanations

### 5. Test Specifications Quality
- [ ] Covers all test cases from request
- [ ] Has exact payloads
- [ ] Has expected outputs
- [ ] Has verification steps

## How to Run

```bash
./02-gate-1-spec-validation/run-gate-1.sh [workflow-name]
```

## Output

Creates a report in `02-gate-1-spec-validation/reports/[workflow-name]-gate-1-report.md`

## Pass Criteria

**PASS** if:
- All required files exist
- All 12 architecture sections present
- No critical errors found
- Errors count = 0

**FAIL** if:
- Any required file missing
- Any required section missing
- Critical errors found
- Errors count > 0

## What Happens on Pass
- Workflow status updated to "stage-2"
- User instructed to proceed to Claude Code
- Architecture is locked (copy made for reference)

## What Happens on Fail
- Workflow status remains "stage-1"
- Error report generated
- User must fix errors and re-run Gate 1
- Cannot proceed to Stage 2

## Validators

### spec-completeness.js
Checks that all required sections exist in architecture document.

### requirements-checker.js
Validates that all business requirements from original request are addressed in architecture.

### architecture-validator.js
Validates technical completeness:
- Node specifications
- Connection map
- Error handling
- Security considerations

## Common Failures

### Missing Sections
**Problem**: Architecture missing one of 12 required sections
**Fix**: Add the missing section to architecture.md

### Incomplete Node Specifications
**Problem**: Nodes don't have type/purpose/inputs/outputs
**Fix**: Complete node specifications in architecture

### No Error Handling
**Problem**: Error handling strategy section empty
**Fix**: Document how each failure point is handled

### Hardcoded Credentials
**Problem**: Configuration JSON has API keys
**Fix**: Replace with environment variable references

### Vague Requirements
**Problem**: Specifications not specific enough
**Fix**: Add details (WHAT, HOW, WHY for each decision)

## Manual Override

**Not recommended**, but if you must bypass Gate 1:
```bash
./pipeline-control/advance-stage.sh [workflow-name] stage-2 --force
```

**Warning**: Bypassing gates means errors will be found later in the pipeline, wasting time.

## Report Format

```markdown
# Gate 1 Validation Report
**Workflow**: [name]
**Date**: [timestamp]
**Status**: PASSED / FAILED

## Validation Results
[List of checks and results]

## Errors
[List of errors with severity]

## Warnings
[List of warnings]

## Summary
- Total Errors: [count]
- Total Warnings: [count]
**Status**: ✅ PASSED / ❌ FAILED

### Next Steps
[What to do next]
```

## Development

To add new validators:
1. Create `02-gate-1-spec-validation/validators/[name].js`
2. Export function that takes workflow name
3. Return exit code 0 (pass) or 1 (fail)
4. Add validator call to `run-gate-1.sh`

Example:
```javascript
// validators/my-new-check.js
module.exports = function(workflowName) {
  // Validation logic here
  if (valid) {
    console.log("✓ Check passed");
    process.exit(0);
  } else {
    console.error("❌ Check failed: reason");
    process.exit(1);
  }
};
```
