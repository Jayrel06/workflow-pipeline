# PT LinkedIn Scraper - Test Specs (Streamlined)

## Critical Test Cases

### 1. Pain Discovery Mode - Happy Path
**Input**: Query "physical therapy clinic challenges", limit: 10
**Expected**: 8-10 pain points extracted, categorized, stored
**Validation**: Check pain_points table for new records with source='linkedin'

### 2. Profile Enrichment Mode - Match Decision Maker
**Input**: clinic_id=5, clinic_name="Phoenix Sports PT"
**Expected**: LinkedIn profile found, decision_maker record created with link to clinic
**Validation**: decision_makers table has new record, matched_segments table links clinic to decision maker

### 3. Rate Limit Protection
**Scenario**: Run 15 LinkedIn operations in sequence
**Expected**: Each operation separated by 10+ seconds, total runtime >150 seconds
**Validation**: Check execution logs for timing, workflow should not be flagged by LinkedIn

### 4. CAPTCHA Detection
**Scenario**: LinkedIn shows CAPTCHA during operation
**Expected**: Workflow pauses, Slack alert sent, waits for manual solve
**Validation**: Execution can resume after CAPTCHA cleared, no data loss

### 5. Weekly Operation Budget
**Scenario**: Track operations across multiple runs
**Expected**: Workflow stops at 150 operations/week, sends budget warning
**Validation**: operation_tracker table increments correctly, weekly reset works

---

## Database Setup
```sql
TRUNCATE TABLE pain_points WHERE source = 'linkedin';
TRUNCATE TABLE decision_makers RESTART IDENTITY CASCADE;

-- Create operation tracker table if not exists
CREATE TABLE IF NOT EXISTS linkedin_operation_tracker (
    id SERIAL PRIMARY KEY,
    operation_count INTEGER DEFAULT 0,
    week_start DATE,
    last_reset TIMESTAMP DEFAULT NOW()
);
```

## Success Criteria
- ✅ Pain discovery finds 80%+ valid pain points
- ✅ Profile enrichment matches 70%+ of clinics to decision makers
- ✅ Zero LinkedIn rate limit violations
- ✅ 10-second minimum delay between all operations
- ✅ Weekly budget enforced at 150 operations
