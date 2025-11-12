# PT Intelligent Matching System - Architecture (Streamlined)

## System Overview
**Purpose**: Match pain point categories to clinic types and generate personalized outreach messages
**Trigger**: Scheduled (weekly) or manual
**Processing**: Batch matching of all unmatched clinics against categorized pain points
**Total Nodes**: 12
**Execution Time**: ~5 minutes per 100 clinics

### Data Flow
```
Schedule Trigger → Get Unmatched Clinics → Loop Each Clinic → Match Pain Categories → Generate Outreach Message (Claude) → Store Match → Generate Report → Slack Notification
```

**Matching Logic**:
- Business type → Pain category mapping (e.g., "Sports Medicine" → "scheduling" + "operations")
- Geography-based pain relevance (local Reddit/LinkedIn mentions)
- Severity score weighting (higher severity = higher priority)

## Node Specifications

### 1. Schedule Trigger
- **Type**: n8n-nodes-base.scheduleTrigger
- **Schedule**: Weekly, every Monday at 9 AM
- **Purpose**: Automatically run matching for new clinics

### 2. Manual Trigger Option
- **Type**: n8n-nodes-base.manualTrigger
- **Purpose**: Allow on-demand matching runs

### 3. Get Unmatched Clinics
- **Type**: n8n-nodes-base.postgres
- **Query**: SELECT clinics WHERE NOT EXISTS in matched_segments
- **Purpose**: Fetch clinics needing pain point matching

### 4. Split Clinics
- **Type**: n8n-nodes-base.splitInBatches
- **Batch Size**: 10
- **Purpose**: Process clinics in manageable batches

### 5. Get Relevant Pain Points
- **Type**: n8n-nodes-base.postgres
- **Query**: SELECT pain_points WHERE state = clinic.state ORDER BY severity_score DESC
- **Purpose**: Fetch geographically relevant pain points

### 6. Match Business Type to Pain Category
- **Type**: n8n-nodes-base.code
- **Logic**: Business type keyword mapping
- **Categories**:
  - Sports Medicine → scheduling, operations
  - General PT → emr, billing
  - Orthopedic → operations, staffing
  - Cash-based → marketing, billing

### 7. Filter Top Pain Points
- **Type**: n8n-nodes-base.code
- **Purpose**: Select top 3 pain points for clinic based on match score
- **Scoring**: Business type match (40%) + Severity (30%) + Geography (30%)

### 8. Generate Outreach Message (Claude)
- **Type**: n8n-nodes-base.httpRequest
- **API**: Anthropic Claude API
- **Purpose**: Create personalized outreach message based on clinic + pain points
- **Template**: "Hi [Name], noticed [Pain Point] is common in [City] for [Business Type] clinics..."

### 9. Parse Outreach Message
- **Type**: n8n-nodes-base.code
- **Purpose**: Extract message from Claude response

### 10. Store Match
- **Type**: n8n-nodes-base.postgres
- **Table**: matched_segments
- **Fields**: clinic_id, pain_point_ids (JSONB array), outreach_message, match_score, match_confidence

### 11. Generate Summary Report
- **Type**: n8n-nodes-base.code
- **Purpose**: Create summary of matching run (X clinics matched, Y pain categories, Z high-confidence matches)

### 12. Slack Notification
- **Type**: n8n-nodes-base.httpRequest
- **Purpose**: Send completion report to #pt-intelligence channel

## Integration Points

### Postgres Integration
- **Connection**: Environment variable POSTGRES_CONNECTION_STRING
- **Tables**: clinics_contact_info, pain_points, matched_segments, decision_makers
- **Operations**:
  - SELECT: Fetch unmatched clinics and relevant pain points
  - INSERT: Store matches with outreach messages
  - UPDATE: Mark clinics as matched

### Claude API Integration
- **Endpoint**: https://api.anthropic.com/v1/messages
- **Model**: claude-3-5-sonnet-20241022
- **Purpose**: Generate personalized outreach messages
- **Input**: Clinic details (name, type, location) + Top 3 pain points
- **Output**: 2-3 sentence outreach message
- **Rate Limiting**: 50 requests/minute (n8n handles automatically)

### Slack Integration
- **Webhook URL**: Environment variable SLACK_WEBHOOK_URL
- **Channel**: #pt-intelligence
- **Notifications**:
  - Weekly matching summary (X clinics matched)
  - High-confidence match alerts (>0.8 confidence)
  - Error reports (if matching fails)

## Error Handling

### Database Errors
- Skip clinics with missing required fields (business_type, city, state)
- Log skipped clinics to error table
- Continue processing remaining clinics

### Claude API Errors
- Retry failed message generation 3 times with exponential backoff
- Use fallback generic message if Claude unavailable
- Log API failures for review

### Duplicate Match Prevention
- Check matched_segments table before inserting
- Skip clinics already matched this week
- Update existing matches if re-matching requested

### Data Quality Validation
- Require minimum 3 pain points in category for matching
- Require clinic business_type to be non-null
- Validate outreach message length (50-500 characters)

### Match Confidence Scoring
- **High confidence (>0.8)**: Business type + pain category exact match + local pain points
- **Medium confidence (0.5-0.8)**: Business type or pain category match + some local relevance
- **Low confidence (<0.5)**: Generic pain points, no business type match (skip these)

**Status**: Ready for Implementation
