# PT Intelligent Matching System - Test Specs (Streamlined)

## Critical Test Cases

### 1. Happy Path - Sports Medicine Clinic
**Input**: Clinic: "Phoenix Sports PT" (Sports Medicine) in Phoenix, AZ
**Pain Points Available**: Scheduling (severity 8), Operations (severity 7), Marketing (severity 5)
**Expected**: Matched to scheduling + operations, match_confidence > 0.8, personalized outreach generated
**Validation**: matched_segments table has record with 2-3 pain_point_ids, outreach message mentions specific pain points

### 2. Multiple Clinics Batch Processing
**Input**: 25 unmatched clinics in database
**Expected**: All 25 matched in ~2-3 batches, execution time <3 minutes, all have outreach messages
**Validation**: 25 new records in matched_segments, no duplicate clinic_ids, all have match_confidence scores

### 3. No Matching Pain Points
**Scenario**: Clinic with business_type "Cash-based PT" but only EMR pain points available
**Expected**: Falls back to generic pain categories (scheduling, marketing), lower confidence score (0.5-0.6)
**Validation**: Match still created, confidence < 0.7, outreach message is more generic

### 4. Claude API Failure
**Scenario**: Claude API returns 429 rate limit error
**Expected**: Workflow retries 3 times with backoff, then uses fallback generic message
**Validation**: Match stored with generic message, Slack alert sent, workflow continues

### 5. Geographic Relevance
**Scenario**: Clinic in Phoenix, pain points from Phoenix (3), California (2), null location (5)
**Expected**: Phoenix pain points scored higher, prioritized in top 3
**Validation**: Outreach message references local pain points, match_confidence boosted by geography match

---

## Database Setup
```sql
-- Reset matched segments for testing
TRUNCATE TABLE matched_segments RESTART IDENTITY;

-- Ensure test data exists
INSERT INTO clinics_contact_info (clinic_name, business_type, city, state)
VALUES
  ('Phoenix Sports PT', 'Sports Medicine', 'Phoenix', 'AZ'),
  ('Desert Rehab Center', 'Physical Therapy', 'Phoenix', 'AZ'),
  ('Valley Orthopedic PT', 'Orthopedic', 'Scottsdale', 'AZ');

INSERT INTO pain_points (pain_category, pain_text, severity_score, state, source)
VALUES
  ('scheduling', 'No-show rates at 20%', 8, 'AZ', 'reddit'),
  ('operations', 'EMR takes 5 min per note', 7, 'AZ', 'linkedin'),
  ('marketing', 'Google Ads ROI is terrible', 5, 'AZ', 'reddit');
```

## Success Criteria
- ✅ 90%+ of clinics successfully matched
- ✅ High-confidence matches (>0.8) have business type + category alignment
- ✅ All outreach messages are 50-500 characters
- ✅ No duplicate matches (UNIQUE constraint enforced)
- ✅ Execution time <5 minutes per 100 clinics
- ✅ Claude API failures handled gracefully with fallback

---

## Sample Expected Output

**Match Record**:
```json
{
  "clinic_id": 1,
  "pain_point_ids": [1, 2, 5],
  "outreach_message": "Hi, noticed scheduling challenges like 20% no-shows are common for sports medicine clinics in Phoenix. Many local PT owners are exploring automated reminder systems to reduce no-shows.",
  "match_confidence": 0.85,
  "matched_categories": ["scheduling", "operations"]
}
```

**Slack Report**:
```
🎯 Intelligent Matching Report

Total Clinics Matched: 25
High Confidence: 18 (>0.8)
Medium Confidence: 7 (0.5-0.8)
Top Categories: scheduling, operations, marketing
```
