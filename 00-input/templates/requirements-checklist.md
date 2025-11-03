# Requirements Checklist

Use this checklist to ensure your workflow request has all necessary information before submitting to the pipeline.

## Business Requirements ✓
- [ ] Clear problem statement
- [ ] Target user/client identified
- [ ] Business value explained
- [ ] Priority level specified
- [ ] Timeline provided

## Technical Requirements ✓
- [ ] Trigger type specified (webhook/schedule/manual)
- [ ] Trigger configuration detailed
- [ ] Input data schema provided
- [ ] Required fields identified
- [ ] Optional fields documented

## Processing Logic ✓
- [ ] All steps listed in order
- [ ] Each step has clear input/process/output
- [ ] Error handling defined for each step
- [ ] Edge cases considered
- [ ] Data transformations specified

## Output Requirements ✓
- [ ] Expected output described
- [ ] Output schema provided
- [ ] Success criteria defined
- [ ] Failure scenarios handled

## Integration Requirements ✓
- [ ] All external systems listed
- [ ] API operations specified
- [ ] Authentication methods documented
- [ ] Rate limits considered

## Security Requirements ✓
- [ ] No hardcoded credentials
- [ ] Environment variables listed
- [ ] Input validation specified
- [ ] Error message safety considered
- [ ] Data encryption addressed

## Testing Requirements ✓
- [ ] Happy path test case provided
- [ ] Error test cases included
- [ ] Edge case tests specified
- [ ] Success criteria for each test

## Documentation Requirements ✓
- [ ] Business context clear
- [ ] Technical details complete
- [ ] Dependencies listed
- [ ] Additional context provided

## Completeness Check
**Total items**: 35
**Must complete**: 100% (all items)
**To pass Gate 1**: All checkboxes must be checked

---

## Common Missing Items
Watch out for these frequently omitted requirements:

1. **Error Handling**: Don't forget what happens when things fail
2. **Environment Variables**: List ALL vars needed
3. **Test Cases**: Need both success AND failure cases
4. **Edge Cases**: What happens with unusual input?
5. **Performance**: Response time and throughput expectations
6. **Data Retention**: How long to keep data
7. **Notifications**: Who needs to know what happened
8. **Rollback Plan**: What if this breaks in production

## Pre-Submission Validation
Run this command before submitting:
```bash
./tools/validate-request.sh 00-input/pending/[your-workflow].md
```

This will check for common issues and missing sections.
