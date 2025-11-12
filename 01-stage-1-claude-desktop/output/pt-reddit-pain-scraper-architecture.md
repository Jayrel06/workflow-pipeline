# PT Reddit Pain Scraper - Technical Architecture

## 1. System Overview

### Purpose
Automatically discover and categorize physical therapy clinic owner pain points from Reddit discussions to inform business development and sales targeting.

### Scope
- **Input**: Reddit JSON API (r/physicaltherapy, r/PrivatePractice, r/smallbusiness)
- **Processing**: Fetch posts → Filter owner content → AI categorization → Deduplication
- **Output**: Postgres database + Slack notification

### Constraints
- Reddit JSON API: 60 requests/minute (unofficial endpoint, no auth)
- Claude API: Rate limits based on tier
- Postgres: Local database
- Schedule: Daily at 2:00 AM EST

### Success Criteria
- 50+ unique pain points per week
- 70%+ actionable business problems
- <10% duplicate rate
- 95%+ uptime

---

## 2. Data Flow

```
┌─────────────────┐
│  Schedule Node  │
│   (Daily 2AM)   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│            Loop: For Each Subreddit                     │
│  ┌───────────────────────────────────────────────────┐ │
│  │  1. HTTP Request → Reddit JSON API                │ │
│  │  2. Code Node → Filter Owner Posts                │ │
│  │  3. Loop: For Each Post                           │ │
│  │     ├─ AI Node → Categorize with Claude           │ │
│  │     ├─ Code Node → Dedupe Logic                   │ │
│  │     └─ Postgres → INSERT INTO pain_points         │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  Code Node      │
│  Generate Report│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Slack Webhook  │
│  Send Summary   │
└─────────────────┘
```

---

## 3. Node Specifications

### Node 1: Schedule Trigger
- **Type**: `n8n-nodes-base.scheduleTrigger`
- **Purpose**: Start workflow daily at 2:00 AM EST
- **Config**:
  - Rule: Cron expression `0 2 * * *`
  - Timezone: America/New_York
- **Output**: Single execution trigger
- **Error Handling**: N/A (built-in)

---

### Node 2: Subreddit Configuration
- **Type**: `n8n-nodes-base.set`
- **Purpose**: Define subreddits and scraping parameters
- **Config**:
  - Set manual values:
    ```json
    {
      "subreddits": ["physicaltherapy", "PrivatePractice", "smallbusiness"],
      "limit": 50,
      "timeFilter": "day",
      "painKeywords": {
        "emr": ["emr", "ehr", "documentation", "charting", "software"],
        "billing": ["billing", "insurance", "claims", "reimbursement"],
        "scheduling": ["scheduling", "appointment", "calendar", "booking"],
        "marketing": ["marketing", "patients", "acquisition", "pricing", "cash-based"],
        "operations": ["workflow", "efficiency", "productivity", "burnout"],
        "staffing": ["hiring", "staff", "employees", "training"]
      }
    }
    ```
- **Output**: Configuration object
- **Error Handling**: None needed (static config)

---

### Node 3: Split Subreddits (Loop Over Items)
- **Type**: `n8n-nodes-base.splitInBatches`
- **Purpose**: Process each subreddit one at a time
- **Config**:
  - Batch size: 1
  - Field to split: `subreddits`
- **Output**: One item per subreddit
- **Error Handling**: Continue on empty array

---

### Node 4: Fetch Reddit Posts (HTTP Request)
- **Type**: `n8n-nodes-base.httpRequest`
- **Purpose**: Call Reddit JSON API for subreddit posts
- **Config**:
  - Method: GET
  - URL: `https://www.reddit.com/r/{{ $json.subreddit }}/new.json?limit={{ $json.limit }}&t={{ $json.timeFilter }}`
  - Authentication: None
  - Headers:
    - `User-Agent`: `PT-Intelligence-Bot/1.0 (by /u/YOUR_REDDIT_USERNAME)`
  - Timeout: 30000ms
  - Retry on fail: Yes (3 times, exponential backoff)
- **Input**: Subreddit name, limit, timeFilter
- **Output**: Reddit API response with posts array
- **Error Handling**:
  - 429 (Rate limit): Wait 60s, retry
  - 404: Log error, continue to next subreddit
  - Network error: Retry 3 times, then fail workflow

---

### Node 5: Parse Reddit Response (Code Node)
- **Type**: `n8n-nodes-base.code`
- **Purpose**: Extract post data from Reddit JSON response
- **Config**:
  ```javascript
  const subreddit = $input.item.json.subreddit;
  const response = $input.item.json;

  if (!response.data || !response.data.children) {
    return [];
  }

  const posts = response.data.children.map(child => {
    const post = child.data;
    return {
      subreddit: subreddit,
      title: post.title,
      selftext: post.selftext || '',
      author: post.author,
      score: post.score,
      num_comments: post.num_comments,
      url: `https://www.reddit.com${post.permalink}`,
      created_utc: post.created_utc
    };
  });

  return posts;
  ```
- **Input**: Reddit API response
- **Output**: Array of simplified post objects
- **Error Handling**: Return empty array if parsing fails

---

### Node 6: Filter Owner Posts (Code Node)
- **Type**: `n8n-nodes-base.code`
- **Purpose**: Filter posts for owner pain keywords and relevance
- **Config**:
  ```javascript
  const painKeywords = $node["Subreddit Configuration"].json.painKeywords;
  const allKeywords = Object.values(painKeywords).flat();

  function calculateRelevance(post) {
    const text = `${post.title} ${post.selftext}`.toLowerCase();
    let score = 0;

    // Check for pain keywords
    for (const keyword of allKeywords) {
      if (text.includes(keyword)) score += 1;
    }

    // Check for owner indicators
    const ownerKeywords = ['owner', 'director', 'clinic', 'practice', 'my pt', 'our clinic'];
    for (const keyword of ownerKeywords) {
      if (text.includes(keyword)) score += 2;
    }

    // Check for question indicators (owners asking for help)
    if (text.includes('?') || text.includes('help') || text.includes('advice') || text.includes('recommend')) {
      score += 1;
    }

    return score;
  }

  const filteredPosts = $input.all().filter(item => {
    const post = item.json;
    const relevance = calculateRelevance(post);
    post.relevance_score = relevance;
    return relevance >= 5; // Threshold
  });

  return filteredPosts;
  ```
- **Input**: All Reddit posts
- **Output**: Filtered posts with relevance scores ≥5
- **Error Handling**: If all filtered out, log warning and continue

---

### Node 7: Categorize with Claude (AI Node)
- **Type**: `@n8n/n8n-nodes-langchain.lmChatAnthropic`
- **Purpose**: Use Claude to categorize pain points and extract specific text
- **Config**:
  - Model: claude-sonnet-4-5-20250929
  - API Key: `{{ $env.CLAUDE_API_KEY }}`
  - Temperature: 0.3 (deterministic)
  - Max tokens: 500
  - Prompt:
    ```
    Analyze this PT clinic discussion post and:
    1. Categorize into ONE of: emr, billing, scheduling, marketing, operations, staffing
    2. Extract the specific pain point in 1 clear sentence
    3. Rate severity 1-10

    Post Title: {{ $json.title }}
    Post Text: {{ $json.selftext }}

    Respond ONLY with valid JSON:
    {
      "pain_category": "category",
      "pain_text": "specific problem in one sentence",
      "severity_score": 8
    }
    ```
  - Output parsing: Extract JSON from response
- **Input**: Individual post
- **Output**: Categorized pain point with category, text, severity
- **Error Handling**:
  - If API fails: Set category="uncategorized", continue
  - If JSON parse fails: Store raw response, flag for manual review

---

### Node 8: Deduplicate Check (Postgres)
- **Type**: `n8n-nodes-base.postgres`
- **Purpose**: Check if post URL already exists in database
- **Config**:
  - Operation: Execute Query
  - Query:
    ```sql
    SELECT id, mentions
    FROM pain_points
    WHERE example_urls @> $1::jsonb
    ```
  - Parameters: `[{"url": "{{ $json.url }}"}]`
- **Input**: Categorized pain point with URL
- **Output**: Existing record (if found) or empty
- **Error Handling**:
  - If connection fails: Store in temp JSON file
  - If query fails: Assume new record (fail-safe to insert)

---

### Node 9: Branch: New vs Existing
- **Type**: `n8n-nodes-base.if`
- **Purpose**: Route to INSERT or UPDATE based on dedupe check
- **Config**:
  - Condition: `{{ $json.id }}` exists
  - If exists: Route to UPDATE node
  - If not exists: Route to INSERT node
- **Output**: Routed items
- **Error Handling**: Default to INSERT if condition evaluation fails

---

### Node 10a: INSERT New Pain Point (Postgres)
- **Type**: `n8n-nodes-base.postgres`
- **Purpose**: Insert new pain point into database
- **Config**:
  - Operation: Insert
  - Table: pain_points
  - Columns:
    - source: 'reddit'
    - pain_category: `{{ $json.pain_category }}`
    - pain_text: `{{ $json.pain_text }}`
    - severity_score: `{{ $json.severity_score }}`
    - mentions: 1
    - example_urls: `[{"url": "{{ $json.url }}", "subreddit": "{{ $json.subreddit }}"}]`
  - Return fields: id, created_at
- **Input**: New pain point
- **Output**: Inserted row with ID
- **Error Handling**:
  - Retry 3 times on failure
  - If still fails: Append to backup JSON file

---

### Node 10b: UPDATE Existing Pain Point (Postgres)
- **Type**: `n8n-nodes-base.postgres`
- **Purpose**: Increment mentions count for duplicate pain points
- **Config**:
  - Operation: Update
  - Table: pain_points
  - Filter: WHERE id = `{{ $json.id }}`
  - Update:
    - mentions: `mentions + 1`
    - example_urls: `example_urls || $1::jsonb` (append new URL)
  - Return fields: id, mentions
- **Input**: Existing pain point with ID
- **Output**: Updated row
- **Error Handling**: Retry 3 times, log if fails

---

### Node 11: Merge Results
- **Type**: `n8n-nodes-base.merge`
- **Purpose**: Combine INSERT and UPDATE results
- **Config**:
  - Mode: Append
  - Input 1: INSERT results
  - Input 2: UPDATE results
- **Output**: All database operation results
- **Error Handling**: N/A (pass-through)

---

### Node 12: Generate Summary Report (Code Node)
- **Type**: `n8n-nodes-base.code`
- **Purpose**: Create daily summary of scraped pain points
- **Config**:
  ```javascript
  const allResults = $input.all();
  const inserts = allResults.filter(r => r.json.operation === 'insert');
  const updates = allResults.filter(r => r.json.operation === 'update');

  // Group by category
  const byCategory = {};
  for (const result of inserts) {
    const cat = result.json.pain_category;
    if (!byCategory[cat]) {
      byCategory[cat] = { count: 0, examples: [] };
    }
    byCategory[cat].count++;
    byCategory[cat].examples.push(result.json.pain_text);
  }

  // Format markdown report
  let report = `📊 **Reddit Pain Point Summary - ${new Date().toISOString().split('T')[0]}**\n\n`;
  report += `**Total Posts Scraped**: ${$node["Parse Reddit Response"].outputItems.length}\n`;
  report += `**Posts Filtered**: ${$node["Filter Owner Posts"].outputItems.length}\n`;
  report += `**New Pain Points**: ${inserts.length}\n`;
  report += `**Updated Pain Points**: ${updates.length}\n\n`;

  report += `**By Category**:\n`;
  for (const [category, data] of Object.entries(byCategory)) {
    report += `\n**${category.toUpperCase()}** (${data.count} mentions)\n`;
    report += `- ${data.examples[0]}\n`;
  }

  return [{ json: { report, stats: { inserts: inserts.length, updates: updates.length } } }];
  ```
- **Input**: All database operation results
- **Output**: Formatted markdown report
- **Error Handling**: If formatting fails, send raw JSON

---

### Node 13: Send Slack Notification
- **Type**: `n8n-nodes-base.httpRequest`
- **Purpose**: Send daily summary to Slack channel
- **Config**:
  - Method: POST
  - URL: `{{ $env.SLACK_WEBHOOK_URL }}`
  - Headers:
    - Content-Type: application/json
  - Body:
    ```json
    {
      "text": "{{ $json.report }}",
      "channel": "#pt-intelligence"
    }
    ```
  - Retry on fail: Yes (2 times)
- **Input**: Summary report
- **Output**: Slack API response
- **Error Handling**:
  - If Slack fails: Send email via SMTP node (backup)
  - If both fail: Log error, don't block workflow

---

### Node 14: Error Handler (Global)
- **Type**: `n8n-nodes-base.errorTrigger`
- **Purpose**: Catch all workflow errors and alert
- **Config**:
  - Trigger on: Any node error
  - Execute: Send error details to Slack
  - Include: Error message, failed node, input data
- **Output**: Error notification sent
- **Error Handling**: Best effort notification

---

## 4. Integration Points

### Reddit JSON API
- **Endpoint**: `https://www.reddit.com/r/{subreddit}/new.json`
- **Authentication**: None (unofficial endpoint)
- **Rate Limits**: ~60 requests/minute (1 per second is safe)
- **Strategy**: Add 2-second delay between subreddit fetches
- **Fallback**: If 429 received, wait 60s and retry

### Claude API (Anthropic)
- **Endpoint**: Via n8n LangChain node
- **Authentication**: API key in environment variable
- **Rate Limits**: Tier-dependent (check dashboard)
- **Strategy**: Process posts sequentially to avoid rate limit
- **Fallback**: If fails, mark as "uncategorized" and continue

### Postgres Database
- **Connection**: `postgresql://user:pass@localhost:5432/pt_clinic_intel`
- **Authentication**: Password in environment variable
- **Tables**: `pain_points`
- **Strategy**: Batch operations where possible
- **Fallback**: Save to temp JSON file if connection fails

### Slack Webhook
- **Endpoint**: Configured webhook URL
- **Authentication**: URL contains secret token
- **Rate Limits**: ~1 request/second
- **Strategy**: Single notification per workflow run
- **Fallback**: Email via SMTP if Slack fails

---

## 5. Error Handling

### Failure Scenarios & Recovery

| Scenario | Detection | Recovery | Fallback |
|----------|-----------|----------|----------|
| **Reddit API Down** | HTTP 500/503 | Retry 3 times with exponential backoff | Skip subreddit, continue with others |
| **Reddit Rate Limit** | HTTP 429 | Wait 60s, retry once | Skip if still rate limited |
| **Claude API Failure** | HTTP 5xx error | Mark posts as "uncategorized" | Continue workflow, flag for manual review |
| **Postgres Connection Lost** | Connection timeout | Save to `/tmp/reddit-pain-backup-{timestamp}.json` | Schedule retry workflow in 1 hour |
| **Slack Webhook Failure** | HTTP error | Fallback to email notification | Log error if both fail |
| **Invalid JSON Response** | JSON.parse() error | Log raw response | Skip post, continue with next |
| **No Posts Found** | Empty array after filtering | Log warning | Complete workflow normally |
| **Workflow Timeout** | n8n timeout (30 min default) | Checkpoint progress at each subreddit | Resume from last completed subreddit |

### Monitoring & Alerts
- **Success Rate**: Track in `workflow_execution_stats` table
- **Error Rate**: Alert if >5% of posts fail categorization
- **Data Quality**: Alert if <10 new pain points per week
- **Duplicate Rate**: Alert if >20% duplicates (dedupe logic broken)

---

## 6. Performance Considerations

### Estimated Execution Time
- Reddit fetch (3 subreddits × 50 posts): ~10 seconds
- Filtering: ~2 seconds
- Claude categorization (40 posts): ~40 seconds (1s per post)
- Database operations: ~5 seconds
- **Total**: ~60 seconds per run

### Optimization Strategies
- **Parallel Processing**: Not recommended for Reddit API (rate limits)
- **Batch Operations**: Group database INSERTs in batches of 10
- **Caching**: Cache pain keywords in workflow state
- **Incremental**: Only process posts from last 24 hours

### Resource Usage
- **Memory**: <100 MB (small dataset)
- **CPU**: Low (mostly I/O bound)
- **Network**: ~150 KB per run (API requests)
- **Storage**: ~50 KB per day in Postgres

---

## 7. Security Considerations

### Credentials Management
- ✅ All API keys in environment variables
- ✅ No hardcoded credentials in workflow
- ✅ Postgres password not in workflow JSON
- ✅ Slack webhook URL in environment

### Data Privacy
- ✅ No PII collected (Reddit usernames not stored)
- ✅ Public data only (Reddit posts)
- ✅ No patient health information
- ✅ Business intelligence data (not regulated)

### Input Validation
- ✅ Sanitize Reddit post text (remove SQL injection attempts)
- ✅ Validate JSON structure from Claude API
- ✅ Limit post text length (max 10,000 chars)
- ✅ Validate URLs before storing

---

## 8. Deployment Configuration

### Environment Variables Required
```bash
POSTGRES_CONNECTION_STRING=postgresql://user:pass@localhost:5432/pt_clinic_intel
CLAUDE_API_KEY=sk-ant-...
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
BACKUP_EMAIL=admin@example.com
REDDIT_USER_AGENT=PT-Intelligence-Bot/1.0 (by /u/your_username)
```

### Database Schema
```sql
CREATE TABLE pain_points (
    id SERIAL PRIMARY KEY,
    source VARCHAR(50) NOT NULL DEFAULT 'reddit',
    pain_category VARCHAR(100),
    pain_text TEXT,
    severity_score INTEGER,
    mentions INTEGER DEFAULT 1,
    example_urls JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_pain_category ON pain_points(pain_category);
CREATE INDEX idx_source ON pain_points(source);
CREATE INDEX idx_created_at ON pain_points(created_at DESC);
CREATE INDEX idx_example_urls ON pain_points USING GIN(example_urls);
```

### n8n Settings
- **Timeout**: 10 minutes (longer than estimated execution)
- **Execution Order**: v1 (sequential)
- **Save Data**: On success only (save space)
- **Timezone**: America/New_York
- **Retry**: On fail, max 1 retry

---

## 9. Success Metrics

### Quantitative Goals
- ✅ 50+ unique pain points per week
- ✅ <10% duplicate rate
- ✅ 70%+ of posts correctly categorized
- ✅ 95%+ workflow uptime (daily executions)

### Qualitative Goals
- ✅ Pain points are actionable business problems
- ✅ Categorization aligns with business needs
- ✅ Low manual review burden (<5% of posts)

### Validation Checklist
After 7 days of operation:
- [ ] Review 20 random pain points for quality
- [ ] Check categorization accuracy (manual spot check)
- [ ] Verify deduplication working (no obvious duplicates)
- [ ] Confirm Slack notifications received daily
- [ ] Validate Postgres data integrity

---

## 10. Future Enhancements

### Phase 2 Improvements
1. **Semantic Deduplication**: Use embeddings to find similar pain points (not just exact URL matches)
2. **Trend Analysis**: Track pain point frequency over time, alert on emerging trends
3. **Author Tracking**: Check if Reddit users are verified clinic owners (flair, post history)
4. **Multi-Language**: Support non-English posts (international PT market)
5. **Auto-Reply Bot**: Respond to Reddit posts with helpful resources (engage community)

### Integration Opportunities
- **CRM Sync**: Auto-create pain point records in HubSpot/Salesforce
- **Dashboard**: Real-time visualization of pain trends (Grafana)
- **Email Digest**: Weekly summary email to stakeholders
- **Webhook Output**: Trigger downstream workflows (e.g., LinkedIn profile search)

---

**Architecture Version**: 1.0
**Created**: 2025-11-11
**Author**: Claude Code
**Status**: Ready for Implementation
