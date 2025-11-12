# Workflow Request: PT Clinic Reddit Pain Point Scraper

## Workflow Name
**pt-reddit-pain-scraper**

## Business Context

**What problem does this solve?**
Physical therapy clinic owners struggle with EMR, billing, scheduling, and marketing issues, but finding these pain points manually is time-consuming. This workflow automatically discovers authentic owner pain points from Reddit discussions to inform business development and sales targeting.

**Who is this for?**
- B2B SaaS companies selling to PT clinics
- Consultants offering PT clinic services
- Market researchers studying PT industry

**Why is this needed now?**
- Manual Reddit browsing takes 10+ hours per week
- Pain points are scattered across multiple subreddits
- Need systematic approach to categorize and prioritize problems
- Time-sensitive: Want to identify Q1 2025 pain trends

## Trigger Information

**What starts this workflow?**
- [X] Schedule
- [ ] Manual trigger (for testing)
- [ ] Webhook
- [ ] Another workflow

**Trigger Details:**
- Runs daily at 2:00 AM EST
- Fetches last 24 hours of posts
- Incremental scraping to avoid duplicates

## Input Data

**What data comes into this workflow?**

```json
{
  "subreddits": [
    "physicaltherapy",
    "PrivatePractice",
    "smallbusiness"
  ],
  "limit_per_subreddit": 50,
  "time_filter": "day",
  "pain_keywords": {
    "emr": ["emr", "ehr", "documentation", "charting", "software"],
    "billing": ["billing", "insurance", "claims", "reimbursement"],
    "scheduling": ["scheduling", "appointment", "calendar", "booking"],
    "marketing": ["marketing", "patients", "acquisition", "pricing", "cash-based"],
    "operations": ["workflow", "efficiency", "productivity", "burnout"],
    "staffing": ["hiring", "staff", "employees", "training"]
  }
}
```

**Required Fields:**
- subreddits: Array of subreddit names to scrape
- limit_per_subreddit: Max posts per subreddit (1-100)
- pain_keywords: Object with categories and keyword arrays

## Processing Logic

### Step 1: Fetch Reddit Posts (HTTP Request)
- Input: Subreddit name, limit, time filter
- Process:
  - Call Reddit JSON API: `https://www.reddit.com/r/{subreddit}/new.json?limit=50&t=day`
  - No authentication required (unofficial JSON endpoint)
  - Add User-Agent header to avoid rate limits
- Output: Array of Reddit posts with title, selftext, score, comments, url
- Error handling:
  - If 429 rate limit: Wait 60 seconds, retry once
  - If 404: Skip subreddit, log error
  - If network error: Fail workflow with clear message

### Step 2: Filter Owner Posts (Code Node)
- Input: All Reddit posts
- Process:
  - Check if post title OR body contains pain keywords
  - Check if author has "owner", "director", "clinic" in flair or history
  - Score relevance 1-10 based on keyword density
  - Filter out posts with score < 5
- Output: Filtered posts with relevance scores
- Error handling: If regex fails, log error but continue with remaining posts

### Step 3: Categorize Pain Points (AI Node - Claude)
- Input: Filtered posts
- Process:
  - Send post title + body to Claude Sonnet 4.5
  - Prompt: "Categorize this PT clinic owner problem into: EMR, billing, scheduling, marketing, operations, staffing. Extract the specific pain point in 1 sentence."
  - Parse JSON response
- Output: Categorized pain points with category and extracted text
- Error handling:
  - If AI fails: Mark as "uncategorized" and store raw text
  - If JSON parse fails: Store raw AI response for manual review

### Step 4: Deduplicate (Postgres)
- Input: Categorized pain points
- Process:
  - Check if post URL already exists in `pain_points` table
  - If exists: Skip insertion
  - If new: Calculate similarity to existing pain_text (Levenshtein distance)
  - If >80% similar: Increment mentions count on existing record
  - If unique: Insert new record
- Output: Deduped pain points
- Error handling:
  - If DB connection fails: Store in temp JSON file for retry
  - If constraint violation: Log and skip record

### Step 5: Store in Database (Postgres)
- Input: Deduped pain points
- Process:
  - INSERT INTO pain_points (source, pain_category, pain_text, severity_score, mentions, example_urls, created_at)
  - Store post URL in example_urls JSONB array
  - Set source = 'reddit'
- Output: Inserted row IDs
- Error handling:
  - If INSERT fails: Retry 3 times with exponential backoff
  - If still fails: Send Slack alert with failed records

### Step 6: Generate Daily Summary (Code Node)
- Input: All inserted pain points from this run
- Process:
  - Group by pain_category
  - Count total mentions per category
  - Extract top 3 pain points per category (by relevance score)
  - Format as markdown report
- Output: Markdown summary report
- Error handling: If grouping fails, send raw data dump

### Step 7: Send Slack Notification
- Input: Summary report
- Process:
  - Send to #pt-intelligence Slack channel
  - Include:
    - Total posts scraped
    - New pain points discovered
    - Top 3 categories by mentions
    - Link to full Postgres table
- Output: Success/failure status
- Error handling: If Slack fails, email the report instead

## Expected Output

**What is the final result?**

```json
{
  "run_date": "2025-11-11",
  "total_posts_scraped": 150,
  "posts_filtered": 42,
  "pain_points_inserted": 38,
  "pain_points_updated": 4,
  "summary": {
    "emr": {
      "mentions": 12,
      "top_pain": "EMR doesn't have PT evaluation templates"
    },
    "billing": {
      "mentions": 8,
      "top_pain": "Insurance claims get rejected frequently"
    },
    "marketing": {
      "mentions": 6,
      "top_pain": "Don't know how to price cash-based services"
    }
  },
  "slack_notification_sent": true
}
```

## Error Handling Requirements

| Error Scenario | Detection | Handling Strategy |
|----------------|-----------|-------------------|
| Reddit rate limit (429) | HTTP response code | Wait 60s, retry once, then skip |
| Database connection failure | Postgres timeout | Store in temp JSON, retry workflow in 1 hour |
| Claude API failure | 5xx error | Mark posts as "uncategorized", continue workflow |
| Slack webhook down | HTTP error | Fall back to email notification |
| Duplicate key constraint | Postgres error | Skip insert, log duplicate count |
| Invalid JSON from Reddit | JSON.parse error | Log raw response, skip that post, continue |

## Integration Points

**What external systems does this touch?**

- [X] Reddit (JSON API - no auth)
- [X] Claude API (OpenRouter or direct)
- [X] Postgres database
- [X] Slack webhooks
- [X] Email (backup notification)

## Security Requirements

- [X] No hardcoded credentials
- [X] Input validation (URL sanitization)
- [X] Rate limiting (Reddit: max 60 requests/min)
- [X] Authentication required (Postgres, Claude, Slack)

**Environment Variables:**
```bash
POSTGRES_CONNECTION_STRING=postgresql://user:pass@localhost:5432/pt_clinic_intel
CLAUDE_API_KEY=[Anthropic API key or OpenRouter key]
SLACK_WEBHOOK_URL=[Webhook for #pt-intelligence channel]
BACKUP_EMAIL=[Email for failed notifications]
REDDIT_USER_AGENT=PT-Intelligence-Bot/1.0
```

## Test Cases

### Test Case 1: Happy Path - New Pain Points
**Scenario:** Run scraper on r/physicaltherapy with 10 new posts containing pain points
**Input:**
```json
{
  "subreddits": ["physicaltherapy"],
  "limit_per_subreddit": 10,
  "time_filter": "day"
}
```
**Expected Output:**
- 10 posts fetched
- 7 posts filtered (contain pain keywords)
- 7 pain points categorized by Claude
- 7 new records inserted into Postgres
- Slack notification sent with summary
**Success Criteria:**
- All 7 records in pain_points table
- Slack message contains "7 new pain points"
- No errors in workflow execution log

### Test Case 2: Duplicate Detection
**Scenario:** Scrape posts with 3 new + 2 duplicate pain points
**Input:** Same as above
**Expected Output:**
- 5 posts processed
- 3 new inserts, 2 mentions incremented
- Slack notification: "3 new, 2 updated"
**Success Criteria:**
- Duplicate URLs not re-inserted
- Mentions count incremented by 1 on existing records

### Test Case 3: Reddit Rate Limit
**Scenario:** Reddit returns 429 error
**Input:** Same as above
**Expected Output:**
- Workflow pauses 60 seconds
- Retries request
- If still 429: Skips that subreddit, continues with others
- Error logged in Slack notification
**Success Criteria:**
- Workflow completes without crashing
- Error message in Slack: "Reddit rate limit hit, retried"

### Test Case 4: Claude API Failure
**Scenario:** Claude API returns 500 error for categorization
**Input:** 5 posts to categorize
**Expected Output:**
- 5 posts marked as "uncategorized"
- Raw text stored in pain_text field
- Category set to "uncategorized"
- Slack alert: "Claude API down, 5 posts need manual review"
**Success Criteria:**
- Workflow completes
- All 5 posts stored in DB
- Manual review flag set

### Test Case 5: Database Connection Failure
**Scenario:** Postgres is down/unreachable
**Input:** 10 categorized pain points ready to insert
**Expected Output:**
- Workflow saves pain points to `/tmp/reddit-pain-backup-{timestamp}.json`
- Slack alert: "Database down, saved to backup file"
- Workflow retries in 1 hour (separate retry workflow)
**Success Criteria:**
- JSON file created with all 10 pain points
- No data lost
- Retry scheduled

## Priority

- [X] Critical
- [ ] High
- [ ] Medium
- [ ] Low

**Justification:** This is the foundation for the entire PT clinic intelligence system. Reddit is the safest data source (no auth, no rate limits if done correctly), and this workflow validates the entire pain point discovery approach.

## Timeline

**Deadline:** November 15, 2025 (4 days)
**Why urgent:** Need to validate pain point quality before building more complex LinkedIn/Google Maps scrapers. If Reddit doesn't yield good data, we pivot the strategy.

---

## Additional Notes

### Postgres Schema (Required)
```sql
CREATE TABLE pain_points (
    id SERIAL PRIMARY KEY,
    source VARCHAR(50), -- 'reddit', 'linkedin', 'forum'
    pain_category VARCHAR(100), -- 'emr', 'billing', etc.
    pain_text TEXT,
    severity_score INTEGER,
    mentions INTEGER DEFAULT 1,
    example_urls JSONB, -- Array of source URLs
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_pain_category ON pain_points(pain_category);
CREATE INDEX idx_source ON pain_points(source);
CREATE INDEX idx_created_at ON pain_points(created_at DESC);
```

### Rate Limit Strategy
- Reddit JSON API: Max 60 requests/minute (1 per second is safe)
- Add 2-second delay between subreddit fetches
- Use User-Agent header to identify bot
- If 429 received: Exponential backoff (60s, 120s, then skip)

### Pain Point Quality Criteria
- Must mention a specific problem (not generic complaints)
- Must be from clinic owner/director (check flair, post history)
- Must have actionable business opportunity
- Examples of GOOD pain points:
  - "Our EMR doesn't have templates for PT evaluations"
  - "Insurance billing takes 10+ hours per week"
  - "Lost 3 patients this week because scheduling system double-booked"
- Examples of BAD pain points:
  - "I hate Mondays" (not actionable)
  - "Patient was rude today" (patient complaint, not owner pain)
  - "Traffic was bad" (not business-related)

### Success Metrics
After 7 days of operation, evaluate:
- **Quantity**: 50+ unique pain points discovered
- **Quality**: 70%+ of pain points are actionable business problems
- **Coverage**: Pain points in at least 4 of 6 categories
- **Duplicates**: <10% duplicate rate (deduplication working)
- **Uptime**: 95%+ success rate (minimal Reddit API failures)

If these metrics are met, proceed to build LinkedIn and Google Maps scrapers.
