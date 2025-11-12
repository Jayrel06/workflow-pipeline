# PT LinkedIn Scraper - Architecture (Streamlined)

## System Overview
**Purpose**: Discover pain points from PT clinic owner LinkedIn posts + Enrich clinics with decision maker profiles
**Mode**: Manual only (rate limit risk)
**Max Operations**: 150/week (100 pain posts + 50 profile searches)
**Total Nodes**: 19
**Execution Time**: ~20 minutes per 10 operations (10-second delays)

### Data Flow
```
Manual Trigger → Budget Check → Mode Branch → [Pain Discovery OR Profile Enrichment] → Store Results → Slack Notification
```

**Pain Discovery Path**: Kapture Browser → LinkedIn Search → Extract Posts → Claude Categorization → Store in pain_points
**Profile Enrichment Path**: Get Clinic → Kapture LinkedIn Search → Extract Profile → Store in decision_makers + Link to clinic

## Node Specifications

### 1. Manual Trigger
- **Type**: n8n-nodes-base.manualTrigger
- **Parameters**: None
- **Purpose**: Human-initiated workflow start

### 2. Config: Parameters
- **Type**: n8n-nodes-base.set
- **Parameters**: mode (pain_discovery/profile_enrichment), query, limit, clinic_id
- **Purpose**: Set operation mode and parameters

### 3. Check Weekly Budget
- **Type**: n8n-nodes-base.postgres
- **Query**: SELECT operation_count FROM linkedin_operation_tracker
- **Purpose**: Enforce 150 operations/week limit

### 4. IF: Budget OK?
- **Type**: n8n-nodes-base.if
- **Condition**: operation_count < 150
- **Purpose**: Stop workflow if budget exceeded

### 5. IF: Pain Discovery?
- **Type**: n8n-nodes-base.if
- **Condition**: mode === "pain_discovery"
- **Purpose**: Branch to correct workflow path

### 6. Mock: Pain Discovery (Kapture in production)
- **Type**: n8n-nodes-base.code
- **Purpose**: Extract LinkedIn posts about PT clinic challenges
- **Kapture Tools**: new_tab, navigate, elements

### 7. DB: Get Clinic
- **Type**: n8n-nodes-base.postgres
- **Purpose**: Fetch clinic details for profile enrichment mode

### 8. Mock: Profile Enrichment (Kapture in production)
- **Type**: n8n-nodes-base.code
- **Purpose**: Find decision maker LinkedIn profiles for clinics
- **Kapture Tools**: new_tab, navigate, click, dom

### 9. Claude: Categorize Pain
- **Type**: n8n-nodes-base.httpRequest
- **API**: Anthropic Claude API
- **Purpose**: Categorize pain points into 6 categories

### 10. Parse Category
- **Type**: n8n-nodes-base.code
- **Purpose**: Extract category from Claude response

### 11. DB: INSERT Pain Point
- **Type**: n8n-nodes-base.postgres
- **Table**: pain_points
- **Purpose**: Store categorized pain points

### 12. DB: INSERT Decision Maker
- **Type**: n8n-nodes-base.postgres
- **Table**: decision_makers
- **Purpose**: Store decision maker profiles

### 13. DB: Link Clinic to DM
- **Type**: n8n-nodes-base.postgres
- **Table**: matched_segments
- **Purpose**: Link clinics to decision makers

### 14. DB: Increment Operations
- **Type**: n8n-nodes-base.postgres
- **Purpose**: Track operation count for budget enforcement

### 15. Wait: 10 Seconds
- **Type**: n8n-nodes-base.wait
- **Duration**: 10 seconds
- **Purpose**: Rate limit protection

### 16. Generate Report
- **Type**: n8n-nodes-base.code
- **Purpose**: Create summary of scraping results

### 17. Slack: Send Summary
- **Type**: n8n-nodes-base.httpRequest
- **Purpose**: Send completion notification

### 18. Budget Exceeded Error
- **Type**: n8n-nodes-base.set
- **Purpose**: Tag error when budget exceeded

### 19. Slack: Budget Alert
- **Type**: n8n-nodes-base.httpRequest
- **Purpose**: Alert team when budget exceeded

## Integration Points

### Kapture MCP Integration
- **Server URL**: Environment variable KAPTURE_SERVER_URL
- **Tools Used**: new_tab, navigate, click, hover, dom, elements
- **Purpose**: Browser automation for LinkedIn scraping
- **Rate Limiting**: 10-second delays between all operations

### Claude API Integration
- **Endpoint**: https://api.anthropic.com/v1/messages
- **Model**: claude-3-5-sonnet-20241022
- **Purpose**: Categorize pain points into: emr, billing, scheduling, marketing, operations, staffing
- **Authentication**: API key via n8n credentials

### Postgres Integration
- **Connection**: Environment variable POSTGRES_CONNECTION_STRING
- **Tables**: pain_points, decision_makers, matched_segments, linkedin_operation_tracker
- **Operations**: SELECT (duplicate check), INSERT (store data), UPDATE (operation counter)

### Slack Integration
- **Webhook URL**: Environment variable SLACK_WEBHOOK_URL
- **Channel**: #pt-intelligence
- **Notifications**: Completion reports, budget alerts

## Error Handling

### Rate Limit Protection
1. **10-second mandatory delay** between all LinkedIn operations
2. **Weekly budget enforcement**: Stop at 150 operations
3. **Operation tracking**: Increment counter after each operation
4. **Budget alerts**: Slack notification at 140 ops and when limit reached

### CAPTCHA Detection
- Workflow pauses if CAPTCHA detected
- Slack alert sent to team
- Manual intervention required
- Workflow can resume after CAPTCHA cleared

### Failed Extractions
- Skip failed operations, continue workflow
- Log errors to separate error tracking table
- Slack notification with error count

### Database Constraints
- Duplicate detection via UNIQUE constraints on linkedin_url
- Skip duplicate inserts (ON CONFLICT DO NOTHING)
- Maintain data integrity with foreign keys

### Critical Constraints
- **10-second delays** between operations (not 3, not 5, TEN)
- **Manual login only** (no automated auth)
- **Human supervision required** (watch for rate limit warnings)
- **Weekly budget**: 150 operations MAX
- **Stop immediately** if rate limit warning appears
- **Checkpoint progress** every 10 operations

**Status**: Ready for Implementation
