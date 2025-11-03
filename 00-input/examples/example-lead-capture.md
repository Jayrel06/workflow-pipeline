# Example: Roofing Lead Capture Webhook

This is a complete example of a workflow request. Use this as a reference when filling out your own.

---

## Workflow Name
Roofing Lead Capture Webhook

## Business Context
**What problem does this solve?**
When potential customers fill out the contact form on our roofing website, we need to immediately capture their information, store it securely, add it to our CRM, and notify our sales team. Currently, leads are going to email and getting lost.

**Who is this for?**
CoreReceptionAI roofing clients who need reliable lead capture from their websites.

**Why is this needed now?**
Clients are losing ~30% of leads due to email delays and manual data entry errors. Need automated, reliable capture ASAP.

## Trigger Information
**What starts this workflow?**
- [x] Webhook (specify path and method)
- [ ] Schedule (specify cron expression)
- [ ] Manual trigger
- [ ] Another workflow (specify which one)
- [ ] Other: _________

**Trigger Details**:
- Method: POST
- Path: `/webhook/roofing-lead`
- Response mode: Return data to webhook caller
- Expected response time: < 2 seconds

## Input Data
**What data comes into this workflow?**
```json
{
  "name": "Customer full name",
  "phone": "Phone number (may have formatting)",
  "email": "Email address (may be missing)",
  "address": "Property address",
  "service_type": "roof_repair | roof_replacement | inspection | other",
  "message": "Optional message from customer",
  "utm_source": "Marketing source (optional)",
  "utm_campaign": "Marketing campaign (optional)"
}
```

**Required Fields**:
- name: Must have at least first name to personalize communication
- phone: Primary contact method (we call leads immediately)
- address: Need property address for roof inspection scheduling

**Optional Fields**:
- email: Backup contact method
- service_type: Helps prioritize leads
- message: Additional context from customer
- utm_source/utm_campaign: Track marketing effectiveness

## Processing Logic
**Step-by-step, what should happen?**

1. **Validate Required Fields**:
   - Input: Raw webhook payload
   - Process: Check that name, phone, and address exist and are not empty strings
   - Output: Valid payload OR error response
   - Error handling: If validation fails, return 400 error with message "Missing required fields: [list]"

2. **Clean and Format Phone Number**:
   - Input: Raw phone number (may be "(555) 123-4567" or "555-123-4567" or "5551234567")
   - Process: Remove all non-digit characters, ensure 10 digits
   - Output: Formatted as "5551234567"
   - Error handling: If not 10 digits after cleaning, flag for manual review

3. **Generate Unique Lead ID**:
   - Input: Current timestamp + cleaned phone number
   - Process: Create unique ID: YYYYMMDD-HHMMSS-[last4ofphone]
   - Output: lead_id: "20250103-143022-4567"
   - Error handling: None (always succeeds)

4. **Enrich Lead Data**:
   - Input: Validated and cleaned data
   - Process: Add metadata:
     - received_at: ISO8601 timestamp
     - source: "website_form"
     - status: "new"
     - assigned_to: null (will be assigned by sales team)
   - Output: Enriched lead object
   - Error handling: None (always succeeds)

5. **Backup to Google Sheets**:
   - Input: Enriched lead object
   - Process: Append row to "Leads" spreadsheet
   - Output: Row number in sheet
   - Error handling: If Google Sheets fails, log error but continue (don't lose the lead!)

6. **Create HubSpot Contact**:
   - Input: Enriched lead object
   - Process: Create or update contact in HubSpot CRM
     - Use phone as unique identifier
     - Set custom properties: service_type, lead_source, address
   - Output: HubSpot contact ID
   - Error handling: If HubSpot fails, continue to notification step (we have backup in Sheets)

7. **Send Slack Notification to Sales Team**:
   - Input: Lead data + HubSpot contact ID
   - Process: Post to #leads channel with formatted message
   - Output: Slack message timestamp
   - Error handling: If Slack fails, send email instead

8. **Send SMS to Customer (Immediate Response)**:
   - Input: Customer phone number
   - Process: Send via Twilio: "Thanks for contacting [Company]! A roofing specialist will call you within 15 minutes."
   - Output: SMS message SID
   - Error handling: If SMS fails, log error but don't fail the workflow

9. **Return Success Response**:
   - Input: All previous step outputs
   - Process: Create success response with lead_id
   - Output: {"success": true, "lead_id": "20250103-143022-4567", "message": "Lead captured successfully"}
   - Error handling: None

## Expected Output
**What is the final result?**
The workflow returns a success response to the webhook caller, confirming the lead was captured. Behind the scenes:
- Lead stored in Google Sheets (backup)
- Contact created/updated in HubSpot
- Sales team notified via Slack
- Customer received confirmation SMS

**Output Data Schema**:
```json
{
  "success": true,
  "lead_id": "20250103-143022-4567",
  "message": "Lead captured successfully",
  "hubspot_contact_id": "12345",
  "sheet_row": 42
}
```

## Error Handling Requirements
**What can go wrong and how should it be handled?**

| Error Scenario | Detection Method | Handling Strategy |
|---------------|------------------|-------------------|
| Missing required fields | Check name, phone, address exist | Return 400 error immediately |
| Invalid phone format | After cleaning, not 10 digits | Flag for manual review, continue processing |
| Google Sheets API down | API error response | Log error, continue (data in other systems) |
| HubSpot API down | API error response | Log error, continue (backup in Sheets) |
| Slack API down | API error response | Send email notification instead |
| Twilio SMS fails | API error response | Log error, don't fail workflow |

**Fallback Strategy**:
Primary: HubSpot + Slack notification
Fallback 1: If HubSpot fails, data still in Google Sheets + Slack notification
Fallback 2: If Slack fails, email notification sent instead
Last resort: All data in Google Sheets for manual processing

## Data Storage & Backup
**Where is data stored?**
- Primary: HubSpot CRM
- Backup: Google Sheets "Leads Backup" (spreadsheet ID in env var)
- Retention: Indefinite (leads are valuable long-term)

## Notifications
**Who needs to know what?**

| Event | Recipient | Method | Message |
|-------|-----------|--------|---------|
| New lead captured | Sales team | Slack #leads | "New roofing lead: [name] - [address] - [phone] - Service: [type]" |
| Lead captured | Customer | SMS | "Thanks for contacting [Company]! A roofing specialist will call you within 15 minutes." |
| Validation error | Ops team | Slack #errors | "Lead submission failed validation: [details]" |
| API failure (any) | Ops team | Slack #errors | "API error in lead capture: [service] - [error]" |

## Integration Points
**What external systems does this touch?**

- [x] CRM (HubSpot)
- [ ] Email service
- [x] SMS service (Twilio)
- [ ] Calendar
- [x] Google Sheets (backup storage)
- [x] Slack (notifications)

**API Requirements**:
- HubSpot: Create/update contact, set custom properties
- Twilio: Send SMS
- Google Sheets: Append row
- Slack: Post message to channel

## Security Requirements
- [x] No hardcoded credentials (all in environment variables)
- [x] Sensitive data encrypted in transit (HTTPS only)
- [x] Error messages don't leak data (no phone numbers in error responses)
- [x] Input validation/sanitization (prevent injection attacks)
- [x] Rate limiting considered (webhook has rate limit)
- [x] Authentication required: No (public webhook, but path is secret)
- [x] Other: Webhook path should be long/random to prevent spam

## Performance Requirements
- **Response Time**: < 2 seconds (customer is waiting for confirmation)
- **Throughput**: 100 requests/hour (peak traffic)
- **Availability**: 99.5% (a few minutes downtime per week is acceptable)
- **Concurrent Execution**: Yes (multiple leads can submit simultaneously)

## Test Cases
**How will we know this works?**

### Test Case 1: Happy Path
**Scenario**: Complete valid lead submission
**Input**:
```json
{
  "name": "John Smith",
  "phone": "(555) 123-4567",
  "email": "john@example.com",
  "address": "123 Main St, Anytown, CA 90210",
  "service_type": "roof_replacement",
  "message": "Need estimate for asphalt shingle replacement",
  "utm_source": "google",
  "utm_campaign": "summer2025"
}
```
**Expected Output**:
- 200 OK response with lead_id
- Row added to Google Sheets
- HubSpot contact created
- Slack notification sent
- Customer receives SMS

**Success Criteria**:
- Response time < 2 seconds
- All systems updated
- Customer gets SMS within 5 seconds

### Test Case 2: Missing Email (Optional Field)
**Scenario**: Lead without email address
**Input**:
```json
{
  "name": "Jane Doe",
  "phone": "5551234567",
  "address": "456 Oak Ave, Somewhere, CA 90211",
  "service_type": "roof_repair"
}
```
**Expected Output**: Same as Test Case 1 (email is optional)
**Success Criteria**: Workflow completes successfully, HubSpot contact has no email

### Test Case 3: Missing Required Field
**Scenario**: Lead without phone number
**Input**:
```json
{
  "name": "Bob Johnson",
  "email": "bob@example.com",
  "address": "789 Elm St, Nowhere, CA 90212"
}
```
**Expected Output**:
```json
{
  "success": false,
  "error": "Missing required fields: phone"
}
```
**Success Criteria**: 400 error returned, no data stored anywhere

### Test Case 4: Invalid Phone Format
**Scenario**: Phone number with too few digits
**Input**:
```json
{
  "name": "Alice Brown",
  "phone": "555-1234",
  "address": "321 Pine St, Anyplace, CA 90213",
  "service_type": "inspection"
}
```
**Expected Output**: Lead captured but flagged for manual review
**Success Criteria**:
- Lead stored in Google Sheets with "needs_review: true"
- Slack notification mentions "Invalid phone format"
- No SMS sent (can't send to invalid number)

### Test Case 5: HubSpot API Failure
**Scenario**: HubSpot is down
**Input**: Valid complete lead (same as Test Case 1)
**Expected Output**:
- Lead still stored in Google Sheets
- Slack notification sent with warning "HubSpot sync failed"
- Customer still receives SMS
- Response: 200 OK (lead was captured successfully even if HubSpot failed)
**Success Criteria**: Lead not lost, sales team notified of sync issue

### Test Case 6: Complete System Failure
**Scenario**: Google Sheets, HubSpot, AND Slack all fail
**Input**: Valid complete lead
**Expected Output**:
- Workflow logs all errors to n8n execution log
- Email sent to ops team with lead data
- Customer still receives SMS if Twilio is working
**Success Criteria**: Lead data appears in ops email for manual entry

## Dependencies
**What needs to exist before this can work?**
- [x] Environment variables:
  - HUBSPOT_API_KEY
  - GOOGLE_SHEETS_SPREADSHEET_ID
  - SLACK_WEBHOOK_URL or SLACK_BOT_TOKEN
  - TWILIO_ACCOUNT_SID
  - TWILIO_AUTH_TOKEN
  - TWILIO_FROM_NUMBER
  - OPS_EMAIL (for critical failures)

- [x] External services:
  - HubSpot account with API access
  - Google Sheets spreadsheet created with proper headers
  - Slack workspace with #leads channel
  - Twilio account with SMS-enabled number

- [ ] Other workflows: None

- [x] Database/storage:
  - Google Sheets "Leads Backup" spreadsheet
  - Columns: lead_id, timestamp, name, phone, email, address, service_type, message, utm_source, utm_campaign, hubspot_id, status

## Priority
- [x] Critical (blocks other work)
- [ ] High (needed soon)
- [ ] Medium (normal priority)
- [ ] Low (nice to have)

## Timeline
**When is this needed?**
Within 1 week - clients are currently losing leads

## Additional Context
**Anything else the AIs should know?**

**Industry Context**: Roofing leads are extremely time-sensitive. The first company to call usually gets the job. Response within 15 minutes increases close rate by 4x.

**Client Expectations**:
- Immediate response to customer (SMS confirmation)
- Sales team notified within seconds
- Zero lost leads (hence multiple backup systems)
- Manual fallback if automation fails

**Regulatory**:
- SMS opt-in not required for transactional messages (this is a response to their inquiry)
- CAN-SPAM compliance for any follow-up emails
- TCPA compliance for phone calls

**Known Issues**:
- Some website forms send phone numbers with extensions - handle gracefully
- Service type might be free-form text instead of dropdown - normalize if possible
- Address quality varies - don't do validation, just store what they send

**Future Enhancements** (not in v1):
- Address validation via Google Maps API
- Duplicate detection (same phone number within 24 hours)
- Automatic assignment to sales reps based on zip code
- Lead scoring based on service type and source

---

## Pipeline Metadata (Auto-filled by system)
**Status**: `example`
**Current Stage**: `N/A - this is an example`
**Created**: 2025-01-03
**Last Updated**: 2025-01-03
**Errors Found**: `N/A`
**Warnings**: `N/A`
