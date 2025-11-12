# Workflow Request: PT Clinic LinkedIn Scraper (Pain + Profiles)

## Workflow Name
**pt-linkedin-scraper**

## Business Context

**What problem does this solve?**
LinkedIn is the ONLY source that provides both owner pain points AND contact information. However, it's heavily rate-limited and must be handled carefully. This workflow discovers pain points from PT clinic owner posts AND enriches Google Maps clinics with decision-maker names/emails.

**Who is this for?**
- Sales teams needing decision-maker names + pain context
- Marketing for personalized outreach campaigns
- Business development for warm introductions

**Why is this needed now?**
- LinkedIn is 70% contact coverage (vs Reddit's 10%)
- Only place to get owner/director names for cold outreach
- Pain points + personal context = highest quality leads
- CRITICAL: Must respect LinkedIn rate limits or risk account ban

## Trigger Information

**What starts this workflow?**
- [X] Manual trigger ONLY (too risky for auto-schedule)
- [ ] Schedule
- [ ] Webhook
- [ ] Another workflow

**Trigger Details:**
- Run manually once per week
- Max 150 operations per run (100 pain posts + 50 profile searches)
- Requires human supervision throughout
- **NEVER run this automatically**

## Input Data

**What data comes into this workflow?**

```json
{
  "mode": "pain_discovery", // or "profile_enrichment"

  // For pain_discovery mode:
  "search_queries": [
    "physical therapy clinic owner challenges",
    "PT practice management issues",
    "cash-based PT business problems"
  ],
  "max_posts": 100,
  "filters": {
    "titles": ["Owner", "Director", "CEO", "Founder", "Managing Partner"],
    "time_filter": "past-month"
  },

  // For profile_enrichment mode:
  "clinic_names": [
    "Phoenix Elite PT",
    "Dallas Sports Medicine"
  ],
  "max_searches": 50
}
```

**Required Fields:**
- mode: "pain_discovery" OR "profile_enrichment"
- Corresponding fields based on mode

## Processing Logic

### BRANCH A: Pain Discovery Mode

#### Step A1: Initialize Kapture Browser (Linkedin Login)
- Input: None
- Process:
  - Open browser tab via Kapture
  - Navigate to linkedin.com
  - **MANUAL STEP**: User must log in manually (workflow pauses)
  - Wait for login completion (check for feed or profile page)
  - Store session cookies
- Output: Authenticated browser session
- Error handling:
  - If login fails: Abort workflow, don't retry (avoid account lockout)
  - If CAPTCHA appears: Pause, wait for manual solve

#### Step A2: Search for Owner Pain Posts (Kapture)
- Input: Search query
- Process:
  - Navigate to LinkedIn search: `https://www.linkedin.com/search/results/content/?keywords={query}`
  - Wait 5 seconds for results to load
  - Scroll to load more posts (max 3 scrolls)
  - Add 8-second delay between scrolls
- Output: Search results page loaded
- Error handling:
  - If search blocked: Abort immediately, send alert
  - If 0 results: Try next query, log warning

#### Step A3: Extract Post Data (Kapture Elements)
- Input: Search results page
- Process:
  - Use Kapture `elements` with selector: `div.feed-shared-update-v2`
  - For each post (max 100):
    - Post text: Extract from `span[dir="ltr"]`
    - Author name: `span.feed-shared-actor__name`
    - Author title: `span.feed-shared-actor__description`
    - Company name: Extract from title (e.g., "Owner at Phoenix PT")
    - Post date: `span.feed-shared-actor__sub-description`
    - Post URL: Extract from anchor tag
  - Add 5-second delay between post extractions
- Output: Array of post data
- Error handling:
  - If rate limit detected (feed stops loading): Stop immediately, save progress
  - If selector changed: Try fallback selectors, alert if all fail

#### Step A4: Filter for PT Clinic Owners (Code Node)
- Input: All posts
- Process:
  - Check if author title contains: "Owner", "Director", "CEO", "Founder"
  - Check if company name OR post text contains: "physical therapy", "PT", "physiotherapy", "rehab"
  - Check if post asks a question OR discusses a problem (?, "help", "advice", "struggling")
  - Score relevance 1-10
  - Filter out posts with score < 6
- Output: Filtered owner pain posts
- Error handling: If all posts filtered out, alert for review

#### Step A5: Categorize Pain Points (Claude AI)
- Input: Filtered posts
- Process:
  - Send post text to Claude Sonnet 4.5
  - Prompt: "Categorize this PT clinic owner problem into: EMR, billing, scheduling, marketing, operations, staffing. Extract the specific pain point in 1 sentence."
  - Parse JSON response
- Output: Categorized pain points
- Error handling: If AI fails, mark as "uncategorized"

#### Step A6: Store Pain Points (Postgres)
- Input: Categorized pain points
- Process:
  - INSERT INTO pain_points (source, pain_category, pain_text, severity_score, mentions, example_urls, created_at)
  - Set source = 'linkedin'
  - Dedupe against existing LinkedIn URLs
- Output: Inserted row IDs
- Error handling: If INSERT fails, save to backup JSON

#### Step A7: Store Decision Makers (Postgres)
- Input: Author data from posts
- Process:
  - INSERT INTO decision_makers (name, title, company_name, linkedin_url, created_at)
  - Use ON CONFLICT DO NOTHING for linkedin_url (unique)
- Output: Inserted decision maker IDs
- Error handling: If INSERT fails, continue (pain points more important)

### BRANCH B: Profile Enrichment Mode

#### Step B1: Initialize Kapture Browser (Reuse Login)
- Input: None
- Process: Same as Step A1
- Output: Authenticated browser session
- Error handling: Same as Step A1

#### Step B2: Search for Owner Profiles (Kapture)
- Input: Clinic name from Google Maps
- Process:
  - Construct search: `https://www.linkedin.com/search/results/people/?keywords=Owner%20at%20{clinic_name}`
  - Navigate to search page
  - Wait 5 seconds for results
  - Add 10-second delay after each search (strict rate limiting)
- Output: Profile search results
- Error handling:
  - If rate limit hit: Stop immediately, save progress
  - If 0 results: Try variations ("Director at...", "Founder of...")

#### Step B3: Extract Top Profile (Kapture Elements)
- Input: Search results
- Process:
  - Get first result only (most relevant)
  - Extract:
    - Name: `span.entity-result__title-text`
    - Title: `span.entity-result__primary-subtitle`
    - Company: Parse from title
    - Profile URL: `a.app-aware-link`
  - **Do NOT click into profile** (triggers rate limits)
- Output: Basic profile data
- Error handling:
  - If extraction fails: Skip this clinic, continue to next

#### Step B4: Match to Clinic (Code Node)
- Input: Profile data + clinic name
- Process:
  - Fuzzy match company name to clinic name (>80% similar)
  - Verify title contains "Owner", "Director", "Founder", "CEO", "Managing"
  - If both match: Confidence = "high"
  - If only one matches: Confidence = "medium"
  - If neither: Confidence = "low" (skip storage)
- Output: Matched profiles with confidence scores
- Error handling: If no matches above "medium", skip storage

#### Step B5: Store Decision Makers (Postgres)
- Input: Matched profiles
- Process:
  - UPDATE decision_makers SET company_name = {clinic_name}, linkedin_url = {url} WHERE name = {name}
  - If not exists: INSERT new record
  - Link to clinic via company_name (foreign key)
- Output: Updated/inserted IDs
- Error handling: If INSERT fails, save to backup JSON

#### Step B6: Enrich Email (Hunter.io API - FUTURE)
- Input: Name, company_name, website (from clinics_contact_info)
- Process:
  - Call Hunter.io API: `https://api.hunter.io/v2/email-finder?domain={website}&first_name={first}&last_name={last}`
  - Extract email if found
  - Store in decision_makers.email
- Output: Enriched email addresses
- Error handling:
  - If Hunter.io fails: Continue without email
  - If rate limit: Skip remaining emails

### Step 8: Close Browser & Generate Report (Both Modes)
- Input: All operation results
- Process:
  - Close Kapture browser tab
  - Generate report with:
    - Mode executed
    - Pain discovery: X posts, Y pain points, Z decision makers
    - Profile enrichment: X profiles searched, Y matches found
    - Rate limit status: How many operations left
  - Format as markdown
- Output: Summary report
- Error handling: If close fails, log warning

### Step 9: Send Slack Notification
- Input: Summary report
- Process:
  - Send to #pt-intelligence channel
  - Include:
    - Mode run
    - Results summary
    - **Rate limit warning** if >120 operations used
    - Next safe run date (7 days later)
- Output: Notification sent
- Error handling: If Slack fails, email the report

## Expected Output

### Pain Discovery Mode Output:
```json
{
  "mode": "pain_discovery",
  "run_date": "2025-11-11",
  "search_queries_executed": 3,
  "posts_scraped": 87,
  "posts_filtered": 42,
  "pain_points_inserted": 38,
  "decision_makers_added": 35,
  "operations_used": 95,
  "rate_limit_status": "safe",
  "next_safe_run": "2025-11-18"
}
```

### Profile Enrichment Mode Output:
```json
{
  "mode": "profile_enrichment",
  "run_date": "2025-11-11",
  "clinics_searched": 50,
  "profiles_found": 42,
  "high_confidence_matches": 38,
  "decision_makers_updated": 38,
  "emails_found": 15,
  "operations_used": 52,
  "rate_limit_status": "safe",
  "next_safe_run": "2025-11-18"
}
```

## Error Handling Requirements

| Error Scenario | Detection | Handling Strategy |
|----------------|-----------|-------------------|
| LinkedIn rate limit | Search/feed stops loading | **STOP IMMEDIATELY**, save progress, wait 7 days |
| Account restricted | "You've been temporarily restricted" message | **ABORT**, send urgent alert, manual review required |
| CAPTCHA challenge | CAPTCHA form appears | Pause workflow, wait for manual solve, continue |
| Login expired | Redirected to login page | Re-login manually, resume from checkpoint |
| Profile not found | 0 search results | Try 2 variations, then skip clinic |
| Hunter.io rate limit | 429 error | Skip remaining emails, continue workflow |
| Database failure | Postgres timeout | Save to backup JSON, retry in 1 hour |
| Browser crash | Tab ID invalid | Restart browser, resume from checkpoint |

## Integration Points

**What external systems does this touch?**

- [X] LinkedIn (via Kapture browser automation)
- [X] Kapture MCP (browser control)
- [X] Claude API (for pain categorization)
- [X] Hunter.io API (email enrichment)
- [X] Postgres database
- [X] Slack webhooks
- [X] Email (backup notification)

## Security Requirements

- [X] No hardcoded credentials (LinkedIn login is manual)
- [X] Input validation (query sanitization)
- [X] **STRICT rate limiting** (Max 150 operations per week)
- [X] Authentication required (LinkedIn, Postgres, APIs)
- [X] Browser session cleanup after workflow
- [X] **Checkpoint system** (resume if interrupted)

**Environment Variables:**
```bash
POSTGRES_CONNECTION_STRING=postgresql://user:pass@localhost:5432/pt_clinic_intel
CLAUDE_API_KEY=[Anthropic API key]
HUNTER_API_KEY=[Hunter.io API key]
SLACK_WEBHOOK_URL=[Webhook for #pt-intelligence channel]
BACKUP_EMAIL=[Email for failed notifications]
KAPTURE_SERVER_URL=http://localhost:3000
LINKEDIN_ACCOUNT_EMAIL=[For logging manual operations]
```

**CRITICAL - LinkedIn Rate Limit Rules:**
- ⚠️ **MAX 150 operations per week** (100 posts + 50 searches)
- ⚠️ **10-second delays between operations** (not 5, not 3, TEN)
- ⚠️ **Manual login only** (no automated login, ever)
- ⚠️ **Run manually only** (no scheduled triggers)
- ⚠️ **Human supervision required** (watch for rate limit warnings)
- ⚠️ **If restricted: STOP ALL LINKEDIN WORKFLOWS FOR 30 DAYS**

## Test Cases

### Test Case 1: Pain Discovery - Happy Path
**Scenario:** Search for PT owner pain posts, find 20 relevant posts
**Input:**
```json
{
  "mode": "pain_discovery",
  "search_queries": ["physical therapy clinic owner challenges"],
  "max_posts": 20
}
```
**Expected Output:**
- 20 posts scraped
- 15 filtered (owners discussing problems)
- 15 pain points categorized and stored
- 15 decision makers stored
- Operations used: ~25
**Success Criteria:**
- No rate limit warnings
- All pain points categorized
- LinkedIn URLs stored correctly

### Test Case 2: Profile Enrichment - Happy Path
**Scenario:** Search for owners of 10 clinics from Google Maps
**Input:**
```json
{
  "mode": "profile_enrichment",
  "clinic_names": ["Phoenix Elite PT", "Dallas Sports Medicine", ...],
  "max_searches": 10
}
```
**Expected Output:**
- 10 clinics searched
- 8 profiles found (80% success rate)
- 8 decision makers updated
- Operations used: ~12
**Success Criteria:**
- High confidence matches only stored
- Names + titles + LinkedIn URLs captured
- Fuzzy matching works correctly

### Test Case 3: LinkedIn Rate Limit Hit
**Scenario:** LinkedIn detects automation during search
**Input:** Same as Test Case 1
**Expected Output:**
- Scraping stops at post #35
- Checkpoint saved: `/tmp/linkedin-checkpoint-{timestamp}.json`
- Slack alert: "LinkedIn rate limit hit, stopped at 35 posts"
- Workflow status: "paused"
- Next safe run: 7 days from now
**Success Criteria:**
- No account restriction (stopped before ban)
- All scraped data saved
- Clear instructions for manual resume

### Test Case 4: CAPTCHA Challenge
**Scenario:** LinkedIn shows CAPTCHA during scraping
**Input:** Same as Test Case 1
**Expected Output:**
- Workflow pauses immediately
- Screenshot of CAPTCHA sent to Slack
- Alert: "CAPTCHA detected, solve manually and click Resume"
- Workflow waits for manual intervention
- Resumes after CAPTCHA solved
**Success Criteria:**
- Workflow doesn't crash
- Data scraped before CAPTCHA is saved
- Resume works correctly after solve

### Test Case 5: Profile Not Found
**Scenario:** Search for owner of clinic with no LinkedIn presence
**Input:**
```json
{
  "mode": "profile_enrichment",
  "clinic_names": ["Small Town PT Clinic"]
}
```
**Expected Output:**
- Primary search: "Owner at Small Town PT Clinic" - 0 results
- Variation 1: "Director at Small Town PT" - 0 results
- Variation 2: "Founder of Small Town" - 0 results
- Log: "No profile found for Small Town PT Clinic"
- Continue to next clinic
**Success Criteria:**
- Workflow doesn't fail on 0 results
- Tries 3 variations before giving up
- Logs missing profile for manual follow-up

### Test Case 6: Database Connection Failure
**Scenario:** Postgres is down during scraping
**Input:** Same as Test Case 1
**Expected Output:**
- 20 pain points scraped
- Database INSERT fails
- Save to `/tmp/linkedin-backup-{timestamp}.json`
- Slack alert: "Database down, saved 20 pain points to backup"
- Retry scheduled in 1 hour
**Success Criteria:**
- JSON file created with all data
- No data lost
- Retry workflow triggered

## Priority

- [X] Critical
- [ ] High
- [ ] Medium
- [ ] Low

**Justification:** LinkedIn is the ONLY source with both pain points AND contact info. However, it's the riskiest (rate limits, account bans). Must be built carefully and monitored closely.

## Timeline

**Deadline:** November 22, 2025 (11 days)
**Why urgent:** Need decision-maker names to complete the contact enrichment. But NOT urgent enough to rush - account safety is paramount.

---

## Additional Notes

### Postgres Schema (Required)
```sql
-- Already exists from Reddit scraper:
CREATE TABLE pain_points (
    id SERIAL PRIMARY KEY,
    source VARCHAR(50),
    pain_category VARCHAR(100),
    pain_text TEXT,
    severity_score INTEGER,
    mentions INTEGER DEFAULT 1,
    example_urls JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- NEW table for decision makers:
CREATE TABLE decision_makers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    title VARCHAR(255),
    company_name VARCHAR(255),
    linkedin_url VARCHAR(500) UNIQUE,
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_company_name ON decision_makers(company_name);
CREATE INDEX idx_linkedin_url ON decision_makers(linkedin_url);

-- Link to clinics (for matching later):
ALTER TABLE decision_makers ADD COLUMN clinic_id INTEGER REFERENCES clinics_contact_info(id);
```

### LinkedIn Operation Budget
**Total weekly budget: 150 operations**
- Pain discovery: 100 operations
  - 3 search queries × 30 posts each = 90 operations
  - 10 operations buffer for retries
- Profile enrichment: 50 operations
  - 50 clinic searches × 1 operation each = 50 operations

**If budget exceeded:**
- Pause all LinkedIn workflows for 7 days
- Send daily Slack reminder: "LinkedIn cooldown period, X days remaining"
- Auto-resume after cooldown

### Checkpoint & Resume System
**Checkpoint every 10 operations:**
- Save progress to `/tmp/linkedin-checkpoint-{timestamp}.json`
- Include:
  - Mode
  - Last processed item (post URL or clinic name)
  - Operations used so far
  - Scraped data not yet stored

**Resume logic:**
- If workflow fails mid-execution:
  - Load most recent checkpoint
  - Skip already processed items
  - Continue from last checkpoint + 1
  - Add checkpoint operations to total count

### Success Metrics
After 4 weeks of operation (4 manual runs):
- **Pain Points**: 150+ unique LinkedIn pain points
- **Decision Makers**: 200+ owner/director profiles stored
- **Contact Coverage**: 40% of Google Maps clinics have decision maker names
- **Account Safety**: 0 rate limit warnings, 0 restrictions
- **Operation Efficiency**: Average 120 operations per run (under budget)

If account is restricted even once, pause LinkedIn workflows for 60 days and re-evaluate strategy.

### LinkedIn Scraping Safety Rules
1. **Never automate login** - Always manual
2. **Never exceed 150 operations/week** - Hard limit
3. **Always use 10-second delays** - No exceptions
4. **Always supervise execution** - Human in the loop
5. **Stop immediately on warnings** - Don't push it
6. **Use real browser (Kapture)** - No headless
7. **Clear cookies weekly** - Avoid tracking patterns
8. **Randomize timing** - Don't run at same time each week

### Hunter.io Email Finder (Future Enhancement)
- **Cost**: $50/month for 1,000 searches
- **Success rate**: 60-70% for PT clinics
- **Process**:
  1. Get website from clinics_contact_info
  2. Parse name into first + last
  3. Call Hunter API with domain + name
  4. Store email if found
- **Rate limit**: 100 requests/day
- **Batch**: Run after profile enrichment completes

### Fallback Selectors (If LinkedIn Changes DOM)
```javascript
const POST_SELECTORS = {
  primary: 'div.feed-shared-update-v2',
  fallback1: 'div[data-id*="urn:li:activity"]',
  fallback2: 'article.occludable-update'
};

const AUTHOR_NAME_SELECTORS = {
  primary: 'span.feed-shared-actor__name',
  fallback1: 'a.app-aware-link span[dir="ltr"]',
  fallback2: '//span[contains(@class, "actor__name")]'
};

const PROFILE_SELECTORS = {
  primary: 'span.entity-result__title-text',
  fallback1: 'div.entity-result__title-text span',
  fallback2: 'a.app-aware-link span[aria-hidden="true"]'
};
```

### Manual Intervention Points
This workflow requires human intervention at:
1. **Login** - User must log in manually
2. **CAPTCHA** - User must solve CAPTCHA if appears
3. **Rate limit** - User must approve continuation or stop
4. **Account restriction** - User must investigate and resolve
5. **Weekly approval** - User must approve each weekly run

**This is NOT a set-it-and-forget-it workflow. It's semi-automated with human oversight.**
