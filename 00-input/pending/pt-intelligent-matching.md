# Workflow Request: PT Clinic Intelligent Matching System

## Workflow Name
**pt-intelligent-matching**

## Business Context

**What problem does this solve?**
We have pain points from Reddit/LinkedIn and contact info from Google Maps, but they're disconnected. This workflow intelligently matches pain categories to clinic types, creating targeted segments for personalized outreach. It answers: "Which clinics should I contact about which problems?"

**Who is this for?**
- Sales teams for targeted cold outreach
- Marketing for segment-specific campaigns
- Business development for solution positioning

**Why is this needed now?**
- 300+ pain points and 500+ clinics, but no mapping between them
- Manual matching would take weeks
- Need to prioritize highest-value segments first
- Time-sensitive: Want to launch outreach campaigns by December 2025

## Trigger Information

**What starts this workflow?**
- [ ] Manual trigger (run after new data is loaded)
- [X] Schedule (daily at 3:00 AM, after all scrapers complete)
- [ ] Webhook
- [X] Another workflow (triggered after Reddit/LinkedIn/Google Maps scrapers)

**Trigger Details:**
- Runs daily after midnight scraping completes
- Re-matches ALL data (not incremental) for freshness
- Takes 5-10 minutes to complete
- Outputs updated segments for same-day outreach

## Input Data

**What data comes into this workflow?**

```json
{
  "matching_strategies": [
    "geographic",
    "business_type",
    "pain_pattern"
  ],
  "priority_pain_categories": ["emr", "billing", "marketing"],
  "min_confidence_score": 7,
  "output_formats": ["json", "csv", "markdown"]
}
```

**Required Fields:**
- matching_strategies: Array of strategies to use
- min_confidence_score: Minimum match confidence (1-10)

## Processing Logic

### Step 1: Load Pain Points (Postgres Query)
- Input: None (pulls from database)
- Process:
  - SELECT * FROM pain_points WHERE created_at > NOW() - INTERVAL '30 days'
  - Group by pain_category
  - Aggregate:
    - Total mentions per category
    - Average severity score
    - Most common pain_text
    - Geographic mentions (if any)
- Output: Aggregated pain points by category
- Error handling:
  - If query fails: Retry 3 times
  - If 0 results: Alert (no new pain points scraped)

### Step 2: Load Clinic Contact Info (Postgres Query)
- Input: None
- Process:
  - SELECT * FROM clinics_contact_info WHERE created_at > NOW() - INTERVAL '30 days' OR updated_at > NOW() - INTERVAL '30 days'
  - Include:
    - clinic_name, phone, website, city, state
    - business_type, rating, review_count
  - Filter: Only clinics with phone OR website (contactable)
- Output: Clinic contact list
- Error handling:
  - If query fails: Retry 3 times
  - If 0 results: Alert (no clinics scraped)

### Step 3: Load Decision Makers (Postgres Query)
- Input: None
- Process:
  - SELECT * FROM decision_makers WHERE created_at > NOW() - INTERVAL '30 days'
  - Join with clinics_contact_info on company_name (fuzzy match)
  - Enrich clinic data with decision maker names
- Output: Clinics with decision maker info
- Error handling:
  - If join fails: Continue without decision makers
  - Log clinics without decision makers for LinkedIn enrichment

### Step 4: MATCHING STRATEGY A - Geographic Targeting
- Input: Pain points + clinics
- Process:
  - For each pain point:
    - Check if pain_text or example_urls mention a location (city/state)
    - Example: "Cash-based PT in Arizona is tough" → Extract "Arizona"
    - Match to clinics in that state
    - Calculate confidence score:
      - Exact city match: +5 points
      - State match: +3 points
      - No geographic mention: 0 points
  - Create segments:
    - Segment name: "{pain_category}-{state}"
    - Target clinics: All clinics in that state
    - Match reason: "Pain point mentioned in {state}, targeting local clinics"
- Output: Geographic segments
- Error handling:
  - If no location extracted: Skip geographic matching
  - Log pain points without location for manual review

### Step 5: MATCHING STRATEGY B - Business Type Targeting
- Input: Pain points + clinics
- Process:
  - For each pain point:
    - Check if pain_text mentions a clinic type:
      - "Sports PT", "cash-based", "multi-location", "solo practice"
    - Match to clinics with corresponding business_type or keywords in name
    - Calculate confidence score:
      - Business type exact match: +5 points
      - Keyword in clinic name: +3 points
      - No type mention: 0 points
  - Create segments:
    - Segment name: "{pain_category}-{business_type}"
    - Target clinics: All clinics of that type
    - Match reason: "Pain point specific to {business_type} clinics"
- Output: Business type segments
- Error handling:
  - If business_type NULL: Try extracting from clinic_name
  - If still NULL: Assign to "general" segment

### Step 6: MATCHING STRATEGY C - Pain Pattern Detection (Advanced)
- Input: Pain points + clinics + clinic_patterns (optional table)
- Process:
  - For each pain_category:
    - Check if clinic_patterns table has matching pattern_type
    - Example: pain_category="scheduling" → pattern_type="scheduling_chaos"
    - Match pain point to clinics with that pattern detected
    - Calculate confidence score:
      - High confidence pattern + pain match: +8 points
      - Medium confidence pattern: +5 points
      - No pattern data: 0 points
  - Create segments:
    - Segment name: "{pain_category}-pattern-detected"
    - Target clinics: Clinics with systemic issues in that category
    - Match reason: "Clinic shows evidence of {pain_category} problems in reviews"
- Output: Pattern-based segments
- Error handling:
  - If clinic_patterns table empty: Skip this strategy
  - Log that pattern analysis needed for better matching

### Step 7: Calculate Priority Scores (AI-Enhanced)
- Input: All segments from strategies A, B, C
- Process:
  - For each segment:
    - Base score = sum of confidence points from all strategies
    - Multiply by pain severity (1-10)
    - Multiply by mentions (frequency)
    - Add bonus points:
      - Has decision maker: +2 points
      - Has email: +3 points
      - Has website: +1 point
      - High review count (>50): +1 point (popular clinic)
    - Normalize to 1-10 scale
  - Send top 10 segments to Claude for qualitative ranking:
    - Prompt: "Rank these PT clinic segments by business opportunity. Consider: market size, pain severity, solution fit."
    - Claude adjusts priority scores
- Output: Prioritized segments with scores 1-10
- Error handling:
  - If Claude fails: Use quantitative scores only
  - If scores all similar: Rank by pain mentions (frequency)

### Step 8: Deduplicate Clinics Across Segments
- Input: Prioritized segments
- Process:
  - Check if same clinic appears in multiple segments
  - If duplicate:
    - Keep clinic in highest priority segment only
    - OR: Create "multi-pain" segment for clinics matching 3+ pain categories
  - Flag clinics with multiple pain points (hot leads)
- Output: Deduped segments
- Error handling:
  - If deduplication removes >50% of clinics: Log warning (over-segmentation)

### Step 9: Generate Personalized Outreach Messages (Claude)
- Input: Each segment
- Process:
  - For each segment, send to Claude:
    - Pain points in segment
    - Clinic characteristics (business type, location)
    - Decision maker name (if available)
  - Prompt: "Draft a cold outreach email subject line and opening sentence for a PT clinic owner struggling with {pain_category}. Personalize for {business_type} in {city}."
  - Claude generates:
    - Email subject line
    - Opening paragraph
    - Suggested call-to-action
- Output: Segment with outreach templates
- Error handling:
  - If Claude fails: Use generic template
  - Log segments needing manual template creation

### Step 10: Store Matched Segments (Postgres)
- Input: Final prioritized segments with outreach templates
- Process:
  - TRUNCATE TABLE matched_segments (clear old matches)
  - INSERT INTO matched_segments (segment_name, pain_category, clinic_id, match_reason, priority_score, outreach_template, created_at)
  - Batch insert for performance
- Output: Inserted segment IDs
- Error handling:
  - If INSERT fails: Retry 3 times
  - If still fails: Save to backup JSON

### Step 11: Generate Segment Report (Markdown)
- Input: All segments
- Process:
  - Format as markdown report:
    - Executive summary (top 5 segments)
    - Full segment breakdown:
      - Segment name
      - Pain category
      - # of clinics
      - Match strategy used
      - Priority score
      - Example clinic
      - Suggested outreach
    - Appendix: Clinics without matches (for manual review)
- Output: `SEGMENT-REPORT-{date}.md`
- Error handling:
  - If formatting fails: Output raw JSON

### Step 12: Export for Sales (CSV + JSON)
- Input: All segments
- Process:
  - Generate CSV: `segments-{date}.csv`
    - Columns: clinic_name, phone, website, city, state, segment, pain_category, priority_score, decision_maker_name, outreach_subject
  - Generate JSON: `segments-{date}.json`
    - Full structured data with nested outreach templates
  - Save to `outputs/` directory
- Output: CSV + JSON files
- Error handling:
  - If file write fails: Retry 3 times
  - If still fails: Store in database only

### Step 13: Send Slack Notification
- Input: Summary stats + top 5 segments
- Process:
  - Send to #pt-intelligence channel
  - Include:
    - Total segments created
    - Total clinics matched
    - Top 5 priority segments (names + scores)
    - Link to full report
    - Link to CSV download
    - Unmatched clinics count
- Output: Notification sent
- Error handling:
  - If Slack fails: Email the summary

## Expected Output

**What is the final result?**

```json
{
  "run_date": "2025-11-11",
  "total_pain_points_analyzed": 320,
  "total_clinics_analyzed": 487,
  "segments_created": 18,
  "clinics_matched": 452,
  "clinics_unmatched": 35,
  "top_5_segments": [
    {
      "segment_name": "emr-frustration-arizona",
      "pain_category": "emr",
      "clinic_count": 47,
      "priority_score": 9.2,
      "match_strategy": "geographic + business_type",
      "avg_confidence": 8.5,
      "has_decision_makers": 32,
      "outreach_subject": "PT-specific EMR alternative for Arizona clinics"
    },
    {
      "segment_name": "cash-based-pricing-texas",
      "pain_category": "marketing",
      "clinic_count": 63,
      "priority_score": 8.9,
      "match_strategy": "geographic + business_type",
      "avg_confidence": 8.1,
      "has_decision_makers": 45,
      "outreach_subject": "Pricing strategy for cash-based PT in Texas"
    }
  ],
  "files_generated": [
    "outputs/segments-2025-11-11.csv",
    "outputs/segments-2025-11-11.json",
    "outputs/SEGMENT-REPORT-2025-11-11.md"
  ],
  "slack_notification_sent": true
}
```

## Error Handling Requirements

| Error Scenario | Detection | Handling Strategy |
|----------------|-----------|-------------------|
| No pain points found | Empty query result | Alert: "Reddit/LinkedIn scrapers may have failed" |
| No clinics found | Empty query result | Alert: "Google Maps scraper may have failed" |
| All segments below min confidence | All scores < threshold | Lower threshold to 5, re-run matching |
| Claude API failure | 5xx error | Use quantitative scoring only, skip templates |
| Database INSERT failure | Postgres error | Save segments to backup JSON, retry in 1 hour |
| Duplicate segment names | Constraint violation | Append timestamp to segment name |
| >90% clinics unmatched | Unmatched count too high | Alert: "Matching logic may need adjustment" |

## Integration Points

**What external systems does this touch?**

- [X] Postgres database (pain_points, clinics_contact_info, decision_makers, matched_segments)
- [X] Claude API (for qualitative ranking + outreach templates)
- [X] File system (CSV + JSON exports)
- [X] Slack webhooks
- [X] Email (backup notification)

## Security Requirements

- [X] No hardcoded credentials
- [X] Input validation (segment names sanitized)
- [X] Rate limiting (N/A - internal processing)
- [X] Authentication required (Postgres, Claude, Slack)
- [ ] PII handling (clinic data is public, decision makers require care)

**Environment Variables:**
```bash
POSTGRES_CONNECTION_STRING=postgresql://user:pass@localhost:5432/pt_clinic_intel
CLAUDE_API_KEY=[Anthropic API key]
SLACK_WEBHOOK_URL=[Webhook for #pt-intelligence channel]
BACKUP_EMAIL=[Email for failed notifications]
OUTPUT_DIRECTORY=/path/to/outputs/ (default: ./outputs/)
```

**Data Privacy Notes:**
- Clinic contact info is publicly available (Google Maps)
- Pain points are anonymized (Reddit usernames not stored)
- Decision maker names are from public LinkedIn profiles
- No HIPAA/PHI data involved (business data only)

## Test Cases

### Test Case 1: Happy Path - Full Matching
**Scenario:** Match 100 pain points to 200 clinics
**Input:**
```json
{
  "matching_strategies": ["geographic", "business_type", "pain_pattern"],
  "min_confidence_score": 7
}
```
**Expected Output:**
- 15-20 segments created
- 180+ clinics matched (90% match rate)
- Top segment priority score >8.5
- All segments have outreach templates
- CSV + JSON + markdown reports generated
**Success Criteria:**
- At least 80% of clinics matched
- No duplicate clinics in top 10 segments
- All priority scores between 1-10

### Test Case 2: Geographic Matching Only
**Scenario:** Pain point mentions "Arizona", match to AZ clinics
**Input:**
```json
{
  "matching_strategies": ["geographic"],
  "min_confidence_score": 5
}
```
**Expected Output:**
- Segment: "emr-arizona"
- 47 AZ clinics matched
- Match reason: "Pain point mentioned in Arizona"
- Priority score: 7.5
**Success Criteria:**
- Only AZ clinics in segment
- Confidence scores all >5
- Geographic extraction working

### Test Case 3: Business Type Matching
**Scenario:** Pain point mentions "cash-based PT", match to cash-based clinics
**Input:**
```json
{
  "matching_strategies": ["business_type"]
}
```
**Expected Output:**
- Segment: "marketing-cash-based"
- 63 cash-based clinics matched
- Match reason: "Pain point specific to cash-based practices"
- Priority score: 8.9
**Success Criteria:**
- Only cash-based clinics in segment
- Business type extracted correctly
- Keyword matching working

### Test Case 4: Multi-Pain Hot Leads
**Scenario:** Some clinics match 3+ pain categories
**Input:** Same as Test Case 1
**Expected Output:**
- Segment: "multi-pain-hot-leads"
- 12 clinics flagged
- Match reason: "Matches 3+ pain categories"
- Priority score: 9.8 (highest)
**Success Criteria:**
- Clinics removed from other segments
- Concentrated in single high-value segment
- Flagged for priority outreach

### Test Case 5: Low Confidence - No Matches
**Scenario:** Pain points are too vague to match confidently
**Input:**
```json
{
  "min_confidence_score": 9
}
```
**Expected Output:**
- 0 segments created (all below threshold)
- Alert: "All segments below confidence threshold, consider lowering to 7"
- Workflow auto-retries with threshold=7
- 10 segments created on retry
**Success Criteria:**
- Threshold adjustment works
- No crash on empty results
- Retry logic successful

### Test Case 6: Claude API Failure
**Scenario:** Claude API is down, can't generate templates
**Input:** Same as Test Case 1
**Expected Output:**
- Matching completes normally
- Priority scores use quantitative only
- Outreach templates set to NULL
- Alert: "Claude API down, manual templates needed"
- Segments still exported without templates
**Success Criteria:**
- Workflow completes
- All segments have priority scores
- Template generation failure doesn't block matching

### Test Case 7: Database Connection Failure
**Scenario:** Postgres is down, can't store segments
**Input:** Same as Test Case 1
**Expected Output:**
- Matching completes in-memory
- All segments saved to `/tmp/segments-backup-{timestamp}.json`
- Alert: "Database down, segments saved to backup file"
- CSV + JSON exports still generated (from backup)
**Success Criteria:**
- No data lost
- Exports work without database
- Retry mechanism triggered

## Priority

- [X] Critical
- [ ] High
- [ ] Medium
- [ ] Low

**Justification:** This is the FINAL piece that makes the entire system valuable. Without matching, we have disconnected data. With matching, we have actionable sales intelligence.

## Timeline

**Deadline:** November 25, 2025 (14 days)
**Why urgent:** Need to complete matching before launching outreach campaigns in December 2025. All upstream scrapers must be complete first.

---

## Additional Notes

### Postgres Schema (Required)
```sql
-- NEW table for matched segments:
CREATE TABLE matched_segments (
    id SERIAL PRIMARY KEY,
    segment_name VARCHAR(255) NOT NULL,
    pain_category VARCHAR(100),
    clinic_id INTEGER REFERENCES clinics_contact_info(id),
    match_reason TEXT,
    match_strategy VARCHAR(100), -- geographic, business_type, pain_pattern
    confidence_score DECIMAL(3,1), -- 1.0 to 10.0
    priority_score DECIMAL(3,1), -- 1.0 to 10.0
    outreach_template JSONB, -- {subject, opening, cta}
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_segment_name ON matched_segments(segment_name);
CREATE INDEX idx_pain_category ON matched_segments(pain_category);
CREATE INDEX idx_priority_score ON matched_segments(priority_score DESC);
CREATE INDEX idx_clinic_id ON matched_segments(clinic_id);
```

### Matching Algorithm Details

**Geographic Extraction (NLP):**
```javascript
// Extract locations from pain_text
const locations = extractLocations(pain_text);
// → ["Arizona", "Phoenix", "TX", "Dallas"]

// Match to clinics
const matchedClinics = clinics.filter(c =>
  locations.includes(c.state) ||
  locations.includes(c.city)
);
```

**Business Type Extraction:**
```javascript
// Keywords mapping
const typeKeywords = {
  "cash-based": ["cash", "out of pocket", "self-pay"],
  "sports-medicine": ["sports", "athletic", "performance"],
  "multi-location": ["multiple", "franchise", "chain"],
  "solo-practice": ["solo", "single", "independent"]
};

// Match clinic business_type to keywords
```

**Confidence Score Calculation:**
```javascript
let score = 0;

// Geographic match
if (pain mentions location && clinic in that location) score += 5;

// Business type match
if (pain mentions type && clinic is that type) score += 5;

// Pattern match
if (clinic has pattern AND pain category matches) score += 8;

// Decision maker available
if (clinic has decision_maker) score += 2;

// Contactability
if (clinic has email) score += 3;
else if (clinic has phone) score += 1;

return Math.min(score, 10); // Cap at 10
```

### Priority Score Formula
```javascript
priority_score = (
  confidence_score *
  pain_severity *
  (mentions / 10) * // Normalize mentions
  (has_decision_maker ? 1.2 : 1.0) * // 20% bonus
  (has_email ? 1.3 : 1.0) // 30% bonus
);

// Normalize to 1-10 scale
priority_score = Math.min(priority_score, 10);
priority_score = Math.max(priority_score, 1);
```

### Segment Naming Convention
```
{pain_category}-{qualifier}-{location}

Examples:
- emr-frustration-arizona
- cash-based-pricing-texas
- billing-insurance-multi-location
- scheduling-chaos-pattern-detected
- multi-pain-hot-leads (special segment)
```

### Output File Formats

**CSV Format:**
```csv
segment_name,clinic_name,phone,website,city,state,pain_category,priority_score,decision_maker,outreach_subject
emr-frustration-arizona,Phoenix Elite PT,(602) 555-1234,phoenixelitept.com,Phoenix,AZ,emr,9.2,John Smith,PT-specific EMR alternative for Arizona clinics
```

**JSON Format:**
```json
{
  "segment_name": "emr-frustration-arizona",
  "pain_category": "emr",
  "priority_score": 9.2,
  "clinics": [
    {
      "clinic_id": 123,
      "clinic_name": "Phoenix Elite PT",
      "phone": "(602) 555-1234",
      "website": "phoenixelitept.com",
      "city": "Phoenix",
      "state": "AZ",
      "decision_maker": {
        "name": "John Smith",
        "title": "Owner & PT",
        "linkedin_url": "linkedin.com/in/johnsmith"
      },
      "match_reason": "Geographic match + EMR pain mentioned in AZ",
      "confidence_score": 8.5
    }
  ],
  "outreach_template": {
    "subject": "PT-specific EMR alternative for Arizona clinics",
    "opening": "Hi {name}, I noticed several PT clinic owners in Arizona discussing EMR documentation challenges...",
    "cta": "Would you be open to a 15-minute call to discuss how we're helping AZ clinics streamline documentation?"
  }
}
```

**Markdown Report Format:**
```markdown
# PT Clinic Segment Report - 2025-11-11

## Executive Summary
- Total Pain Points: 320
- Total Clinics: 487
- Segments Created: 18
- Match Rate: 93%

## Top 5 Priority Segments

### 1. EMR Frustration - Arizona (Score: 9.2)
- **Pain Category:** EMR
- **Clinics:** 47
- **Decision Makers:** 32 (68%)
- **Match Strategy:** Geographic + Business Type
- **Example Pain:** "Current EMR doesn't have PT evaluation templates"
- **Outreach Angle:** PT-specific EMR alternative

**Sample Clinic:**
- Name: Phoenix Elite PT
- Contact: John Smith (Owner)
- Phone: (602) 555-1234
- Website: phoenixelitept.com

[Continue for all segments...]
```

### Success Metrics
After 7 days of matching (7 runs):
- **Match Rate**: 85%+ of clinics matched to segments
- **Segment Count**: 15-25 meaningful segments (not too few, not too many)
- **Confidence**: Average confidence score >7.0
- **Priority Distribution**: Top 10 segments contain 60% of clinics
- **Outreach Templates**: 90%+ of segments have AI-generated templates
- **Sales Adoption**: Sales team uses segments for 80%+ of outreach

### Integration with Sales CRM (Future Enhancement)
**Post-MVP**: Export segments directly to CRM
- HubSpot: Use API to create contacts + lists
- Salesforce: Use API to create leads + campaigns
- Close.io: Use API to create opportunities
- **Auto-sync**: Daily segment updates push to CRM

### Segment Refresh Strategy
- **Daily**: Re-match all data (clinics may move segments as new pain points discovered)
- **Weekly**: Archive old segments, create fresh segments
- **Monthly**: Review segment performance (which segments convert best)
- **Quarterly**: Adjust matching algorithm based on sales feedback
