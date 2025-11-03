# Workflow Request Template

**Instructions**: Copy this file to `00-input/pending/[your-workflow-name].md` and fill out ALL sections. Incomplete requests will fail Gate 1 validation.

---

## Workflow Name
[Short, descriptive name - Example: "Lead Capture Webhook"]

## Business Context
**What problem does this solve?**
[Explain the business need]

**Who is this for?**
[Target user/client]

**Why is this needed now?**
[Urgency/priority]

## Trigger Information
**What starts this workflow?**
- [ ] Webhook (specify path and method)
- [ ] Schedule (specify cron expression)
- [ ] Manual trigger
- [ ] Another workflow (specify which one)
- [ ] Other: _________

**Trigger Details**:
[Provide specific configuration]

## Input Data
**What data comes into this workflow?**
```json
{
  "field_name": "data_type and description",
  "example": "actual example value"
}
```

**Required Fields**:
- [Field 1]: [Why required]
- [Field 2]: [Why required]

**Optional Fields**:
- [Field 1]: [What it's used for]

## Processing Logic
**Step-by-step, what should happen?**

1. **[Step Name]**: [Detailed description of what happens]
   - Input: [What data this step receives]
   - Process: [What transformation/action occurs]
   - Output: [What data this step produces]
   - Error handling: [What happens if this step fails]

2. **[Step Name]**: [Description]
   - Input:
   - Process:
   - Output:
   - Error handling:

[Continue for all steps...]

## Expected Output
**What is the final result?**

[Describe what happens at the end - data created, APIs called, notifications sent, etc.]

**Output Data Schema**:
```json
{
  "output_field": "description"
}
```

## Error Handling Requirements
**What can go wrong and how should it be handled?**

| Error Scenario | Detection Method | Handling Strategy |
|---------------|------------------|-------------------|
| [Error 1] | [How to detect] | [What to do] |
| [Error 2] | [How to detect] | [What to do] |

**Fallback Strategy**:
[If primary method fails, what's the backup plan?]

## Data Storage & Backup
**Where is data stored?**
- Primary: [Main storage location]
- Backup: [Backup storage - e.g., Google Sheets]
- Retention: [How long to keep data]

## Notifications
**Who needs to know what?**

| Event | Recipient | Method | Message |
|-------|-----------|--------|---------|
| Success | [Who] | [Email/Slack/SMS] | [What to say] |
| Failure | [Who] | [Email/Slack/SMS] | [What to say] |

## Integration Points
**What external systems does this touch?**

- [ ] CRM (specify: HubSpot, Salesforce, etc.)
- [ ] Email service (specify: SendGrid, etc.)
- [ ] SMS service (specify: Twilio, etc.)
- [ ] Calendar (specify: Google Calendar, etc.)
- [ ] Other: _________

**API Requirements**:
- [Service 1]: [What operations - create, read, update?]
- [Service 2]: [What operations?]

## Security Requirements
- [ ] No hardcoded credentials (all in environment variables)
- [ ] Sensitive data encrypted in transit
- [ ] Error messages don't leak data
- [ ] Input validation/sanitization
- [ ] Rate limiting considered
- [ ] Authentication required: Yes / No
- [ ] Other: _________

## Performance Requirements
- **Response Time**: [Target - e.g., < 2 seconds]
- **Throughput**: [Volume - e.g., 100 requests/hour]
- **Availability**: [Uptime - e.g., 99.5%]
- **Concurrent Execution**: [Yes/No - can multiple run at once?]

## Test Cases
**How will we know this works?**

### Test Case 1: Happy Path
**Scenario**: [Normal operation]
**Input**:
```json
{
  "test": "data"
}
```
**Expected Output**: [What should happen]
**Success Criteria**: [How to verify]

### Test Case 2: Missing Required Field
**Scenario**: [Error condition]
**Input**:
```json
{
  "incomplete": "data"
}
```
**Expected Output**: [Error handling]
**Success Criteria**: [Graceful failure]

### Test Case 3: [Additional Test]
[Continue for all major scenarios...]

## Dependencies
**What needs to exist before this can work?**
- [ ] Environment variables: [List them]
- [ ] External services: [Which ones need to be configured?]
- [ ] Other workflows: [Any dependencies?]
- [ ] Database/storage: [What needs to be set up?]

## Priority
- [ ] Critical (blocks other work)
- [ ] High (needed soon)
- [ ] Medium (normal priority)
- [ ] Low (nice to have)

## Timeline
**When is this needed?**
[Deadline or timeframe]

## Additional Context
**Anything else the AIs should know?**

[Industry-specific considerations, client preferences, regulatory requirements, etc.]

---

## Pipeline Metadata (Auto-filled by system)
**Status**: `pending`
**Current Stage**: `0 - awaiting Stage 1`
**Created**: [timestamp]
**Last Updated**: [timestamp]
**Errors Found**: `0`
**Warnings**: `0`
