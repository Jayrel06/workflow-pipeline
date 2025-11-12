# PT Reddit Pain Scraper - Test Specifications

Complete test cases for validating the workflow.

---

## Test Environment Setup

### Prerequisites
```bash
# 1. Database ready
psql -U postgres -d pt_clinic_intel -c "SELECT COUNT(*) FROM pain_points;"

# 2. Environment variables set
echo $POSTGRES_CONNECTION_STRING
echo $CLAUDE_API_KEY
echo $SLACK_WEBHOOK_URL

# 3. n8n running
curl http://localhost:5678/healthz
```

### Test Data Preparation
```sql
-- Clear test data
TRUNCATE TABLE pain_points RESTART IDENTITY;

-- Verify clean state
SELECT COUNT(*) FROM pain_points; -- Should be 0
```

---

## Test Cases

### Test Case 1: Happy Path - Full Workflow Success

**Objective**: Verify workflow executes end-to-end with real Reddit data

**Input**:
- Trigger: Manual execution
- Subreddits: `["physicaltherapy"]`
- Limit: 10 posts
- Time filter: "week"

**Expected Flow**:
1. Schedule trigger fires
2. Config node sets subreddit list
3. Reddit API returns 10 posts
4. Parse extracts post data
5. Filter identifies 5-7 owner pain posts (relevance ≥5)
6. Claude categorizes all filtered posts
7. Database check finds 0 duplicates (first run)
8. INSERT node adds 5-7 new pain points
9. Report generated with category breakdown
10. Slack notification sent

**Expected Output**:
```json
{
  "stats": {
    "inserts": 6,
    "updates": 0,
    "total": 6,
    "categories": 3
  },
  "slack_sent": true
}
```

**Validation Steps**:
```sql
-- Check database
SELECT COUNT(*) FROM pain_points WHERE source = 'reddit'; -- Should be 5-7

-- Check categories
SELECT pain_category, COUNT(*)
FROM pain_points
GROUP BY pain_category; -- Should show 2-3 categories

-- Check example URLs
SELECT example_urls FROM pain_points LIMIT 1;
-- Should contain Reddit URL array
```

**Success Criteria**:
- ✅ At least 5 pain points inserted
- ✅ All pain_category values are valid (emr, billing, etc.)
- ✅ All severity_score between 1-10
- ✅ Slack notification received in #pt-intelligence
- ✅ No workflow errors

---

### Test Case 2: Duplicate Detection

**Objective**: Verify deduplication prevents re-inserting same Reddit posts

**Input**:
- Same configuration as Test Case 1
- Run workflow twice

**Expected Flow (Second Run)**:
1. Reddit API returns same 10 posts
2. Filter identifies same 6 posts
3. Claude categorizes (may vary slightly)
4. Database check finds 6 existing IDs
5. UPDATE node increments mentions to 2
6. No new INSERTs
7. Report shows 0 inserts, 6 updates

**Expected Output**:
```json
{
  "stats": {
    "inserts": 0,
    "updates": 6,
    "total": 6
  }
}
```

**Validation Steps**:
```sql
-- Check mentions incremented
SELECT url, mentions FROM pain_points WHERE mentions > 1;
-- Should show 6 records with mentions = 2

-- Check example_urls grew
SELECT jsonb_array_length(example_urls) FROM pain_points LIMIT 1;
-- Should be 2 (original + duplicate)
```

**Success Criteria**:
- ✅ No duplicate pain_text entries
- ✅ All mentions = 2 for existing records
- ✅ example_urls array contains 2 entries
- ✅ Total record count unchanged (still 6)

---

### Test Case 3: Multi-Subreddit Scraping

**Objective**: Verify workflow processes multiple subreddits sequentially

**Input**:
- Subreddits: `["physicaltherapy", "PrivatePractice", "smallbusiness"]`
- Limit: 20 per subreddit
- Time filter: "week"

**Expected Flow**:
1. Loop processes subreddit 1: physicaltherapy
   - Wait 2s, fetch 20 posts, filter, categorize, store
2. Loop processes subreddit 2: PrivatePractice
   - Wait 2s, fetch 20 posts, filter, categorize, store
3. Loop processes subreddit 3: smallbusiness
   - Wait 2s, fetch 20 posts, filter, categorize, store
4. Report aggregates all 3 subreddits

**Expected Output**:
```json
{
  "stats": {
    "inserts": 15,
    "updates": 0,
    "total": 15,
    "categories": 5
  }
}
```

**Validation Steps**:
```sql
-- Check subreddit distribution
SELECT
  example_urls->0->>'subreddit' as subreddit,
  COUNT(*)
FROM pain_points
GROUP BY subreddit;
-- Should show all 3 subreddits

-- Verify timing (check execution log)
-- Each Reddit API call should be 2+ seconds apart
```

**Success Criteria**:
- ✅ All 3 subreddits processed
- ✅ Pain points from all 3 subreddits in database
- ✅ No rate limit errors (429)
- ✅ Total execution time ~60-90 seconds

---

### Test Case 4: Reddit API Rate Limit (429)

**Objective**: Verify workflow handles rate limiting gracefully

**Setup**: Reduce delay to 0.5s (trigger rate limit intentionally)

**Expected Flow**:
1. First request succeeds
2. Second request returns 429
3. HTTP node retry logic waits 5s
4. Retry succeeds
5. Workflow continues normally

**Expected Output**:
- Workflow completes with some delay
- No errors thrown
- All posts eventually processed

**Validation Steps**:
- Check execution log for retry messages
- Verify final database count matches expected

**Success Criteria**:
- ✅ Workflow doesn't fail on 429
- ✅ Retry mechanism works
- ✅ All data eventually stored

---

### Test Case 5: Claude API Failure

**Objective**: Verify workflow continues when Claude API is down/fails

**Setup**: Temporarily break Claude API (invalid key or disconnect network)

**Expected Flow**:
1. Reddit posts fetched normally
2. Claude categorization fails
3. Parse AI Response catches error
4. Falls back to:
   - pain_category = "uncategorized"
   - pain_text = post title
   - severity_score = 5
5. Database INSERT continues with fallback data
6. Report shows "uncategorized" category

**Expected Output**:
```json
{
  "stats": {
    "inserts": 6,
    "updates": 0,
    "total": 6,
    "categories": 1
  }
}
```

**Validation Steps**:
```sql
-- Check for uncategorized pain points
SELECT COUNT(*) FROM pain_points WHERE pain_category = 'uncategorized';
-- Should be > 0

-- Check for AI error flag
SELECT ai_error, raw_ai_response
FROM pain_points
WHERE pain_category = 'uncategorized'
LIMIT 1;
-- Should contain error details
```

**Success Criteria**:
- ✅ Workflow completes (doesn't fail)
- ✅ Pain points stored with "uncategorized" category
- ✅ Error details logged for manual review
- ✅ Slack notification mentions AI failure

---

### Test Case 6: Database Connection Failure

**Objective**: Verify workflow saves data to backup file if database is down

**Setup**: Stop Postgres or break connection string

**Expected Flow**:
1. Reddit posts fetched and categorized normally
2. Database INSERT fails
3. Error handler catches failure
4. Data saved to `/tmp/reddit-pain-backup-{timestamp}.json`
5. Slack alert sent: "Database down, saved to backup file"

**Expected Output**:
- Workflow marked as "error" but data preserved
- Backup JSON file created

**Validation Steps**:
```bash
# Check backup file exists
ls -la /tmp/reddit-pain-backup-*.json

# Validate JSON structure
cat /tmp/reddit-pain-backup-*.json | jq '.stats'
# Should show insert/update counts

# Verify can restore data
psql -U postgres -d pt_clinic_intel -c "\COPY pain_points ..."
```

**Success Criteria**:
- ✅ Backup file created with all pain points
- ✅ JSON is valid and complete
- ✅ Slack alert sent with file path
- ✅ No data lost

---

### Test Case 7: Empty Results (No Matching Posts)

**Objective**: Verify workflow handles empty filter results gracefully

**Setup**: Use very high relevance threshold (e.g., ≥50) to filter all posts

**Expected Flow**:
1. Reddit API returns 10 posts
2. Filter applies threshold
3. 0 posts match criteria
4. Workflow continues with empty array
5. Report shows 0 inserts, 0 updates
6. Slack notification: "No new pain points discovered today"

**Expected Output**:
```json
{
  "stats": {
    "inserts": 0,
    "updates": 0,
    "total": 0,
    "categories": 0
  }
}
```

**Validation Steps**:
- Check workflow execution log (success, not error)
- Verify Slack notification received
- Check database count unchanged

**Success Criteria**:
- ✅ Workflow completes successfully
- ✅ No errors thrown
- ✅ Database unchanged
- ✅ Slack notification sent

---

### Test Case 8: Invalid JSON from Claude

**Objective**: Verify workflow handles malformed AI responses

**Setup**: Mock Claude to return non-JSON text

**Expected Flow**:
1. Posts categorized by Claude
2. Claude returns non-JSON response (e.g., "I cannot categorize this")
3. Parse AI Response catches JSON.parse error
4. Fallback to default values
5. Continue with uncategorized pain point

**Expected Output**:
- Pain point stored with category="uncategorized"
- raw_ai_response field contains actual response

**Validation Steps**:
```sql
SELECT pain_category, raw_ai_response
FROM pain_points
WHERE ai_error IS NOT NULL;
-- Should show malformed responses
```

**Success Criteria**:
- ✅ Workflow doesn't crash
- ✅ Fallback logic works
- ✅ Raw response preserved for debugging

---

### Test Case 9: Long Post Text (Edge Case)

**Objective**: Verify workflow handles very long Reddit posts

**Setup**: Find post with 10,000+ character selftext

**Expected Flow**:
1. Post fetched with full text
2. Claude processes long text (may truncate internally)
3. Categorization succeeds
4. Database stores full text (TEXT field, no limit)
5. Workflow completes normally

**Expected Output**:
- Pain point stored with full text

**Validation Steps**:
```sql
SELECT LENGTH(pain_text), pain_text
FROM pain_points
WHERE LENGTH(pain_text) > 100
LIMIT 1;
-- Should show long text stored correctly
```

**Success Criteria**:
- ✅ Long text doesn't break workflow
- ✅ Database stores full content
- ✅ Claude handles gracefully (may summarize)

---

### Test Case 10: Scheduled Execution

**Objective**: Verify workflow runs automatically on schedule

**Setup**: Set schedule to run in 2 minutes, wait for execution

**Expected Flow**:
1. n8n scheduler triggers at specified time
2. Workflow executes normally
3. Results stored in database
4. Slack notification sent

**Validation Steps**:
- Check n8n execution history (should show automatic execution)
- Verify database updated with new records
- Check Slack notification timestamp matches schedule

**Success Criteria**:
- ✅ Workflow triggers on schedule
- ✅ Executes without manual intervention
- ✅ Results match manual execution

---

## Performance Tests

### Test Case 11: Large Batch (100 Posts)

**Objective**: Verify workflow handles large batches efficiently

**Input**:
- Limit: 100 posts per subreddit
- 3 subreddits = 300 total posts
- Expected filtered: ~50 posts

**Expected Timing**:
- Reddit fetch: 10s (3 requests × 3s)
- Filtering: 2s
- Claude categorization: 50s (50 posts × 1s)
- Database operations: 5s
- **Total**: ~70 seconds

**Validation**:
- Check execution time in n8n
- Verify all posts processed
- No timeouts

**Success Criteria**:
- ✅ Completes in <5 minutes
- ✅ No memory issues
- ✅ All data accurate

---

### Test Case 12: Concurrent Executions (Load Test)

**Objective**: Verify workflow handles overlapping executions

**Setup**: Trigger workflow 3 times manually (rapid succession)

**Expected Behavior**:
- n8n queues executions
- Each execution processes independently
- No race conditions in database
- All 3 complete successfully

**Validation**:
- Check execution queue in n8n
- Verify database integrity (no constraint violations)

**Success Criteria**:
- ✅ All executions complete
- ✅ No database conflicts
- ✅ Data integrity maintained

---

## Data Quality Tests

### Test Case 13: Category Accuracy

**Objective**: Validate Claude categorization accuracy

**Manual Review**:
1. Run workflow with 20 posts
2. Manually review 10 random pain points
3. Check if category matches content

**Success Criteria**:
- ✅ 80%+ correctly categorized
- ✅ No obviously wrong categories
- ✅ Severity scores reasonable (5-9 for real pain points)

---

### Test Case 14: Deduplication Accuracy

**Objective**: Verify dedupe logic catches duplicates correctly

**Test**:
1. Run workflow twice on same subreddit/timeframe
2. Check for any duplicate pain_text entries
3. Verify example_urls array growth

**Validation**:
```sql
-- Check for duplicate pain text
SELECT pain_text, COUNT(*)
FROM pain_points
GROUP BY pain_text
HAVING COUNT(*) > 1;
-- Should return 0 rows
```

**Success Criteria**:
- ✅ No duplicate pain_text entries
- ✅ All example_urls arrays have 2+ entries
- ✅ Mentions counts incremented correctly

---

## Security Tests

### Test Case 15: SQL Injection Prevention

**Objective**: Verify workflow sanitizes inputs

**Setup**: Mock Reddit post with malicious content:
```json
{
  "title": "Test'; DROP TABLE pain_points;--",
  "selftext": "Malicious content"
}
```

**Expected Behavior**:
- Parameterized queries prevent injection
- Data stored safely with special characters
- Database unaffected

**Success Criteria**:
- ✅ pain_points table intact
- ✅ Malicious text stored as string (not executed)

---

### Test Case 16: API Key Security

**Objective**: Verify credentials not exposed in logs

**Validation**:
- Check n8n execution logs
- Ensure no API keys visible
- Verify environment variables used

**Success Criteria**:
- ✅ No API keys in logs
- ✅ No connection strings in logs

---

## Regression Test Suite

After any code changes, run this quick validation:

```bash
# 1. Happy path test
curl -X POST http://localhost:5678/webhook/test-reddit-scraper

# 2. Check database
psql -U postgres -d pt_clinic_intel -c "SELECT COUNT(*) FROM pain_points WHERE created_at > NOW() - INTERVAL '5 minutes';"

# 3. Verify Slack notification
# Check #pt-intelligence channel for recent message

# 4. Check for errors
# Review n8n execution log for any red flags
```

**Pass Criteria**: All 4 checks succeed

---

## Test Metrics

Track these metrics over 7 days:

| Metric | Target | Actual |
|--------|--------|--------|
| Workflow success rate | 95%+ | |
| Pain points per day | 10-20 | |
| Duplicate rate | <10% | |
| Categorization accuracy | 70%+ | |
| Avg execution time | <90s | |
| API failures | <5% | |

---

## Troubleshooting Guide

### Issue: Workflow times out
**Check**:
- Reddit API response time
- Claude API response time
- Database query performance

**Fix**: Increase timeout in workflow settings

### Issue: 0 pain points discovered
**Check**:
- Reddit API returning data?
- Filter threshold too high?
- Pain keywords too specific?

**Fix**: Review and adjust filter criteria

### Issue: Database connection refused
**Check**:
- Postgres running?
- Connection string correct?
- Firewall blocking?

**Fix**: Restart Postgres, verify credentials

### Issue: Slack notifications not received
**Check**:
- Webhook URL valid?
- Channel exists?
- Webhook not disabled?

**Fix**: Test webhook URL with curl

---

**Test Suite Version**: 1.0
**Last Updated**: 2025-11-11
**Estimated Test Execution Time**: 2-3 hours for full suite
