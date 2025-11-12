# Workflow Request: PT Clinic Google Maps Contact Scraper

## Workflow Name
**pt-google-maps-contacts**

## Business Context

**What problem does this solve?**
We have pain points from Reddit/LinkedIn but no contact information for actual PT clinics. This workflow systematically scrapes contact details (phone, website, address) from Google Maps across target cities, ignoring patient reviews and focusing purely on business contact info.

**Who is this for?**
- Sales teams needing qualified PT clinic leads
- Marketing teams for targeted outreach campaigns
- Business development for partnership opportunities

**Why is this needed now?**
- Need 500 clinics across 5 cities (Phoenix, Dallas, Austin, Seattle, Denver)
- Pain point data is useless without contacts to reach
- Manual Google Maps scraping takes 40+ hours
- Need clean, structured data in Postgres for matching

## Trigger Information

**What starts this workflow?**
- [ ] Manual trigger (run once per city)
- [ ] Schedule (weekly refresh)
- [X] Webhook (triggered after Reddit scraper completes)
- [ ] Another workflow

**Trigger Details:**
- Triggered by completion of Reddit pain scraper (to prioritize cities mentioned in pain points)
- Can also run manually for ad-hoc city scraping
- Processes one city at a time to avoid Google rate limits

## Input Data

**What data comes into this workflow?**

```json
{
  "city": "Phoenix",
  "state": "AZ",
  "search_query": "physical therapy clinic",
  "max_results": 100,
  "filters": {
    "min_rating": 3.0,
    "min_review_count": 5,
    "business_types": ["Physical Therapy", "Sports Medicine", "Rehabilitation"]
  }
}
```

**Required Fields:**
- city: City name (string)
- state: State abbreviation (string)
- search_query: Google Maps search term (string)
- max_results: Max clinics to scrape (1-200)

## Processing Logic

### Step 1: Initialize Kapture Browser Tab
- Input: None (startup step)
- Process:
  - Use Kapture MCP to open new browser tab
  - Navigate to Google Maps homepage
  - Wait for page load
  - Get tab ID for subsequent operations
- Output: Browser tab ID
- Error handling:
  - If Kapture not running: Fail workflow with setup instructions
  - If browser doesn't open: Retry 3 times, then fail

### Step 2: Search Google Maps (Kapture Navigate)
- Input: City, state, search query
- Process:
  - Construct URL: `https://www.google.com/maps/search/physical+therapy+clinic+Phoenix+AZ`
  - Navigate to URL using Kapture
  - Wait 3 seconds for results to load
  - Take screenshot for debugging
- Output: Search results page loaded
- Error handling:
  - If navigation timeout: Retry once with 10s timeout
  - If no results: Log warning, return empty array

### Step 3: Scrape Clinic Listings (Kapture Elements)
- Input: Search results page
- Process:
  - Use Kapture `elements` tool with selector: `div[role="article"]` (clinic cards)
  - Extract from each card:
    - Clinic name: `h3` or `a[aria-label]`
    - Rating: `span[aria-label*="stars"]`
    - Review count: Extract number from aria-label
    - Address snippet: First line of text
  - Collect up to max_results clinic cards
  - Scroll page if needed to load more results
- Output: Array of clinic card data
- Error handling:
  - If selector changes: Try fallback selectors
  - If DOM structure different: Log HTML, send alert
  - If <10 results found: Log warning (possible Google blocking)

### Step 4: Click Each Clinic for Details (Kapture Click + DOM)
- Input: Array of clinic cards
- Process:
  - For each clinic:
    - Click on clinic card (opens detail panel)
    - Wait 2 seconds for panel to load
    - Extract from detail panel:
      - Full address: `button[data-item-id*="address"]`
      - Phone: `button[data-item-id*="phone"]`
      - Website: `a[data-item-id*="website"]`
      - Business type: Category tags
    - Add 3-second delay between clicks (rate limiting)
- Output: Enriched clinic data with full details
- Error handling:
  - If click fails: Try XPath selector
  - If detail panel doesn't load: Skip clinic, log error
  - If phone/website missing: Store as NULL (still valid record)

### Step 5: Filter Out Non-PT Businesses (Code Node)
- Input: All scraped clinics
- Process:
  - Check if business_type contains "Physical Therapy", "Rehabilitation", "Sports Medicine", "Physiotherapy"
  - Check if clinic_name contains "PT", "Physical Therapy", "Rehab"
  - Filter out: Chiropractors, massage, acupuncture (common false positives)
  - Apply rating/review filters from input
- Output: Filtered PT clinics only
- Error handling: If all results filtered out, log alert (possible bad search)

### Step 6: Deduplicate Against Existing Records (Postgres)
- Input: Filtered clinics
- Process:
  - Query clinics_contact_info table for matching phone numbers OR addresses
  - If phone match: Skip (duplicate)
  - If address match (fuzzy matching >90% similar): Skip
  - If no match: Mark for insertion
- Output: New clinics only
- Error handling:
  - If DB query fails: Continue without dedup (will hit constraint on insert)
  - Log duplicate count for metrics

### Step 7: Store in Database (Postgres)
- Input: New clinics
- Process:
  - INSERT INTO clinics_contact_info (clinic_name, address, phone, website, city, state, business_type, rating, review_count, created_at)
  - Batch insert (50 at a time) for performance
  - Use ON CONFLICT DO NOTHING for phone/address (unique constraints)
- Output: Inserted row IDs
- Error handling:
  - If constraint violation: Log skipped clinic
  - If INSERT fails: Save to backup JSON
  - Send Slack alert if >50% fail to insert

### Step 8: Close Browser Tab (Kapture)
- Input: Tab ID from Step 1
- Process:
  - Use Kapture `close` tool to close browser tab
  - Clean up any temp files/screenshots
- Output: Tab closed
- Error handling: If close fails, log warning (not critical)

### Step 9: Generate Scraping Report
- Input: All operation results
- Process:
  - Calculate:
    - Total clinics scraped
    - Clinics filtered out
    - New inserts vs duplicates
    - Missing data (no phone, no website)
  - Format as markdown report
- Output: Summary report
- Error handling: If formatting fails, send raw JSON

### Step 10: Send Slack Notification
- Input: Summary report
- Process:
  - Send to #pt-intelligence channel
  - Include:
    - City/state processed
    - New clinics added to database
    - Total clinics in database now
    - Link to Postgres query
- Output: Notification sent
- Error handling: If Slack fails, email the report

## Expected Output

**What is the final result?**

```json
{
  "city": "Phoenix",
  "state": "AZ",
  "run_date": "2025-11-11",
  "total_scraped": 100,
  "pt_clinics_filtered": 87,
  "duplicates_found": 12,
  "new_inserts": 75,
  "missing_phone": 8,
  "missing_website": 15,
  "database_total": 275,
  "execution_time": "8m 32s",
  "slack_notification_sent": true
}
```

## Error Handling Requirements

| Error Scenario | Detection | Handling Strategy |
|----------------|-----------|-------------------|
| Google blocks scraper (CAPTCHA) | No results after search | Pause workflow, send alert to manually solve CAPTCHA |
| Kapture browser crashes | Tab ID invalid | Restart browser, retry from last checkpoint |
| Rate limit hit (429) | HTTP response code | Pause 5 minutes, retry once |
| Database connection failure | Postgres timeout | Store in backup JSON, retry in 1 hour |
| Phone/website missing | NULL values | Store record anyway (partial data still useful) |
| DOM structure changed | Selectors return 0 results | Try fallback selectors, send alert if all fail |
| Browser timeout | Page doesn't load in 30s | Increase timeout to 60s, retry once |

## Integration Points

**What external systems does this touch?**

- [X] Google Maps (via Kapture browser automation)
- [X] Kapture MCP (browser control)
- [X] Postgres database
- [X] Slack webhooks
- [X] Email (backup notification)

## Security Requirements

- [X] No hardcoded credentials
- [X] Input validation (city/state sanitization)
- [X] Rate limiting (3 seconds between clicks)
- [X] Authentication required (Postgres, Slack)
- [X] Browser session cleanup after workflow

**Environment Variables:**
```bash
POSTGRES_CONNECTION_STRING=postgresql://user:pass@localhost:5432/pt_clinic_intel
SLACK_WEBHOOK_URL=[Webhook for #pt-intelligence channel]
BACKUP_EMAIL=[Email for failed notifications]
KAPTURE_SERVER_URL=http://localhost:3000 (default)
```

**CRITICAL - Patient Review Warning:**
- ⚠️ DO NOT scrape individual patient reviews
- ⚠️ DO NOT analyze review text for pain points
- ⚠️ ONLY extract: name, phone, website, address, rating, review_count
- ⚠️ Review text contains patient complaints, NOT owner pain points

## Test Cases

### Test Case 1: Happy Path - New City
**Scenario:** Scrape Phoenix, AZ for first time (no existing records)
**Input:**
```json
{
  "city": "Phoenix",
  "state": "AZ",
  "search_query": "physical therapy clinic",
  "max_results": 100
}
```
**Expected Output:**
- 100 results scraped
- 80-90 PT clinics filtered
- 75+ new inserts (some may lack phone/website)
- Slack notification: "75 new Phoenix clinics added"
**Success Criteria:**
- All records in clinics_contact_info table
- No duplicate phone numbers
- At least 60% have websites

### Test Case 2: Duplicate Detection
**Scenario:** Re-scrape Phoenix 24 hours later (most should be duplicates)
**Input:** Same as above
**Expected Output:**
- 100 results scraped
- 90+ duplicates detected
- 5-10 new inserts (new clinics opened)
- Slack notification: "5 new, 95 duplicates skipped"
**Success Criteria:**
- No duplicate records inserted
- Database total only increased by 5-10

### Test Case 3: Google CAPTCHA Block
**Scenario:** Google detects automation and shows CAPTCHA
**Input:** Same as above
**Expected Output:**
- Search loads but shows CAPTCHA page
- Workflow detects no results
- Pauses execution
- Slack alert: "Google CAPTCHA detected, manual intervention needed"
- Workflow waits 30 minutes, then retries
**Success Criteria:**
- Workflow doesn't crash
- Clear instructions for manual CAPTCHA solving
- Retry mechanism works after CAPTCHA cleared

### Test Case 4: Missing Contact Info
**Scenario:** Clinic has no website or phone listed on Google Maps
**Input:** Same as above
**Expected Output:**
- Clinic still inserted with NULL website/phone
- Report shows "15 clinics missing website"
- Records flagged for manual enrichment
**Success Criteria:**
- Partial data still stored
- NULL values allowed (not empty strings)
- Count of missing data in report

### Test Case 5: Database Connection Failure
**Scenario:** Postgres is down during scraping
**Input:** Same as above
**Expected Output:**
- Scraping completes normally
- 75 clinics saved to `/tmp/google-maps-backup-phoenix-{timestamp}.json`
- Slack alert: "Database down, saved to backup file"
- Retry scheduled in 1 hour
**Success Criteria:**
- JSON file created with all data
- No data lost
- Retry workflow triggered

### Test Case 6: DOM Structure Changed
**Scenario:** Google Maps changes HTML selectors
**Input:** Same as above
**Expected Output:**
- Primary selectors return 0 results
- Fallback selectors tried: `a[aria-label]`, `div.fontHeadlineSmall`, etc.
- If all fail: Slack alert with screenshot + DOM dump
- Workflow pauses for developer fix
**Success Criteria:**
- Fallback selectors documented
- Clear debugging info (screenshot + HTML)
- Manual override option

## Priority

- [X] Critical
- [ ] High
- [ ] Medium
- [ ] Low

**Justification:** This workflow provides the "WHO to reach" data that complements Reddit pain points (WHAT to say). Both are equally critical for the complete intelligence system.

## Timeline

**Deadline:** November 18, 2025 (1 week)
**Why urgent:** Need contact database before building LinkedIn enrichment and matching system. Estimated 2-3 days to scrape all 5 cities (500 clinics).

---

## Additional Notes

### Postgres Schema (Required)
```sql
CREATE TABLE clinics_contact_info (
    id SERIAL PRIMARY KEY,
    clinic_name VARCHAR(255) NOT NULL,
    address TEXT,
    phone VARCHAR(50),
    website VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    business_type VARCHAR(100),
    rating DECIMAL(2,1),
    review_count INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(phone), -- Prevent duplicate by phone
    UNIQUE(address, city, state) -- Prevent duplicate by address
);

CREATE INDEX idx_city_state ON clinics_contact_info(city, state);
CREATE INDEX idx_business_type ON clinics_contact_info(business_type);
CREATE INDEX idx_rating ON clinics_contact_info(rating);
```

### Target Cities & Expected Counts
| City | State | Expected Clinics | Priority |
|------|-------|-----------------|----------|
| Phoenix | AZ | 120 | High (cash-based market) |
| Dallas | TX | 150 | High (large metro) |
| Austin | TX | 80 | Medium (growing market) |
| Seattle | WA | 100 | Medium (tech-savvy owners) |
| Denver | CO | 50 | Low (smaller market) |
| **TOTAL** | | **500** | |

### Rate Limiting Strategy
- **Between clinic clicks**: 3 seconds (Kapture delay)
- **Between cities**: 1 hour (separate workflow runs)
- **Daily limit**: 200 clinics max per day
- **Reason**: Avoid Google detecting automation patterns

### Success Metrics
After scraping all 5 cities:
- **Quantity**: 500+ clinics total
- **Completeness**: 80%+ have phone OR website (at least one contact method)
- **Quality**: <5% non-PT businesses (filtering works)
- **Duplicates**: <2% duplicate rate across cities
- **Uptime**: 90%+ success rate (minimal Google blocking)

### Google Maps Scraping Best Practices
1. **Use real browser (Kapture)** - Avoid headless detection
2. **Human-like delays** - 3-5 seconds between actions
3. **Randomize timing** - Don't always use exact 3 seconds
4. **Clear cookies periodically** - Prevents session tracking
5. **Rotate search terms** - "physical therapy", "PT clinic", "physiotherapy"
6. **Monitor for CAPTCHA** - Pause immediately if detected

### Fallback Selectors (If Google Changes DOM)
```javascript
const CLINIC_SELECTORS = {
  primary: 'div[role="article"]',
  fallback1: 'a[aria-label*="Physical"]',
  fallback2: 'div.fontHeadlineSmall',
  fallback3: '//div[contains(@class, "place-result")]' // XPath
};

const PHONE_SELECTORS = {
  primary: 'button[data-item-id*="phone"]',
  fallback1: 'a[href^="tel:"]',
  fallback2: '//button[contains(@aria-label, "Phone")]'
};

const WEBSITE_SELECTORS = {
  primary: 'a[data-item-id*="website"]',
  fallback1: 'a[href*="http"]:not([href*="google.com"])',
  fallback2: '//a[contains(text(), "Website")]'
};
```

### Data Quality Checks
After scraping, validate:
- [ ] At least 70% have phone numbers
- [ ] At least 50% have websites
- [ ] All have city/state
- [ ] No duplicate phone numbers
- [ ] No non-PT businesses (spot check 20 random)
- [ ] Rating range is reasonable (1.0-5.0)

If any check fails, alert developer for manual review.

### Backup & Recovery
- **Checkpoint every 25 clinics**: Save progress to temp JSON
- **Resume from checkpoint**: If workflow fails, start from last checkpoint
- **Backup file location**: `/tmp/google-maps-checkpoint-{city}-{timestamp}.json`
- **Retention**: Keep backups for 7 days

### Future Enhancements (Post-MVP)
1. **Pattern Analysis** (Phase 3): Aggregate review text for systemic patterns
2. **Business Hours Scraping**: Extract open/close times for best call times
3. **Photo Analysis**: Check if clinic looks modern (tech adoption indicator)
4. **Directions Analysis**: Check if "hard to find" mentioned (facility issue)
