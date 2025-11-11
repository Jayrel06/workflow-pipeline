# PT Clinic Intelligence System - Test Specifications

**Document Version:** 1.0
**Last Updated:** 2025-01-20
**Author:** Claude Code
**Status:** Production-Ready Testing Guide

---

## Table of Contents

1. [Overview](#overview)
2. [Test Environment Setup](#test-environment-setup)
3. [Test Data Preparation](#test-data-preparation)
4. [Test Case 1: Happy Path (Austin, TX)](#test-case-1-happy-path-austin-tx)
5. [Test Case 2: Small City - Limited Results](#test-case-2-small-city-limited-results)
6. [Test Case 3: Scraping Blocked by Anti-Bot](#test-case-3-scraping-blocked-by-anti-bot)
7. [Test Case 4: Supabase Database Down](#test-case-4-supabase-database-down)
8. [Test Case 5: Claude API Rate Limit](#test-case-5-claude-api-rate-limit)
9. [Test Case 6: Clinics with Zero Reviews](#test-case-6-clinics-with-zero-reviews)
10. [Test Case 7: All Email Verification Failures](#test-case-7-all-email-verification-failures)
11. [Test Case 8: Stress Test (100 Clinics)](#test-case-8-stress-test-100-clinics)
12. [Performance Benchmarks](#performance-benchmarks)
13. [Regression Testing Checklist](#regression-testing-checklist)

---

## Overview

### Purpose

This document provides comprehensive test specifications for validating the PT Clinic Intelligence System workflow in n8n. Each test case includes:

- **Test Objective** - What we're validating
- **Preconditions** - Required setup before test
- **Input Payload** - Exact webhook data to send
- **Expected Behavior** - Step-by-step workflow execution
- **Expected Outputs** - Data at each stage
- **Verification Queries** - SQL/API calls to confirm results
- **Success Criteria** - Pass/fail conditions
- **Edge Cases** - Boundary conditions tested

### Test Strategy

**Testing Levels:**
1. **Integration Tests** (Test Cases 1-7) - Full workflow execution with external APIs
2. **Stress Test** (Test Case 8) - Performance and scalability validation
3. **Regression Tests** - Verify no breaking changes after updates

**Testing Environment:**
- **Development:** Use test API keys and staging Supabase
- **Staging:** Mirror production with synthetic data
- **Production:** Limited smoke tests only (5 clinics max)

---

## Test Environment Setup

### Required Services

1. **n8n Instance** (v1.0+)
   - Installed locally or on cloud server
   - Workflow imported and activated

2. **Playwright Container**
   - Running on `http://localhost:3000` or cloud URL
   - Test with: `curl -X POST http://localhost:3000/health` → `{"status": "ok"}`

3. **Supabase Project** (TEST database)
   - Create separate test project (not production)
   - Run setup SQL:
   ```sql
   -- Test database setup
   CREATE TABLE pt_clinic_leads (
     id BIGSERIAL PRIMARY KEY,
     place_id TEXT UNIQUE NOT NULL,
     name TEXT NOT NULL,
     address TEXT,
     city TEXT,
     state TEXT,
     zip TEXT,
     phone TEXT,
     phone_valid BOOLEAN DEFAULT FALSE,
     website TEXT,
     domain TEXT,
     primary_email TEXT,
     backup_emails JSONB DEFAULT '[]'::jsonb,
     email_confidence INTEGER,
     total_reviews INTEGER,
     average_rating DECIMAL(2,1),
     reviews_analyzed INTEGER,
     pain_categories JSONB DEFAULT '[]'::jsonb,
     primary_pain_point TEXT,
     overall_sentiment TEXT,
     lead_score INTEGER,
     tier TEXT CHECK (tier IN ('A', 'B', 'C')),
     status TEXT DEFAULT 'new',
     email_subject TEXT,
     email_body TEXT,
     email_generated_at TIMESTAMPTZ,
     discovery_count INTEGER DEFAULT 1,
     last_seen TIMESTAMPTZ DEFAULT NOW(),
     created_at TIMESTAMPTZ DEFAULT NOW(),
     updated_at TIMESTAMPTZ DEFAULT NOW()
   );

   CREATE TABLE workflow_errors (
     id BIGSERIAL PRIMARY KEY,
     workflow_name TEXT NOT NULL,
     error_category TEXT NOT NULL,
     error_message TEXT,
     failed_node TEXT,
     recommended_action TEXT,
     place_id TEXT,
     timestamp TIMESTAMPTZ DEFAULT NOW()
   );

   CREATE INDEX idx_place_id ON pt_clinic_leads(place_id);
   CREATE INDEX idx_tier ON pt_clinic_leads(tier);
   CREATE INDEX idx_status ON pt_clinic_leads(status);
   CREATE INDEX idx_created_at ON pt_clinic_leads(created_at DESC);
   ```

4. **API Keys** (Test/Sandbox Mode)
   - `ANTHROPIC_API_KEY` - Claude API (use low-limit test key)
   - `ZEROBOUNCE_API_KEY` - Email verification (use free tier)
   - `GOOGLE_SHEETS_BACKUP_ID` - Test spreadsheet ID
   - `NOTIFICATION_EMAIL` - Your test email address
   - `ADMIN_EMAIL` - Your test email address

5. **Environment Variables** (n8n Settings > Variables)
   ```bash
   SUPABASE_URL=https://test-project.supabase.co
   SUPABASE_ANON_KEY=eyJhbGc...TEST_KEY
   PLAYWRIGHT_CONTAINER_URL=http://localhost:3000
   ANTHROPIC_API_KEY=sk-ant-api03-TEST_KEY
   ZEROBOUNCE_API_KEY=TEST_KEY
   GOOGLE_SHEETS_BACKUP_ID=1ABC123DEF456
   NOTIFICATION_EMAIL=test@example.com
   ADMIN_EMAIL=admin@example.com
   ```

### Pre-Test Checklist

- [ ] All 55 nodes imported and connected
- [ ] All environment variables set
- [ ] Playwright container responding to health check
- [ ] Supabase tables created with indexes
- [ ] Google Sheet created and shared with service account
- [ ] Test API keys have sufficient quota
- [ ] Workflow activated in n8n
- [ ] Webhook URL copied: `https://your-n8n.com/webhook/pt-clinic-discovery`

---

## Test Data Preparation

### Mock Data for Controlled Testing

For some tests, you may want to use mock data instead of live scraping:

**Mock Clinic Data (for Node 6 response):**
```json
{
  "clinics": [
    {
      "place_id": "ChIJTestMock12345",
      "name": "Test PT Clinic",
      "address": "123 Test St, Austin, TX 78701",
      "city": "Austin",
      "state": "TX",
      "zip": "78701",
      "phone": "(512) 555-0100",
      "website": "https://testptclinic.com",
      "rating": 4.2,
      "total_reviews": 87
    }
  ]
}
```

**Mock Review Data (for Node 11 response):**
```json
{
  "place_id": "ChIJTestMock12345",
  "reviews": [
    {
      "rating": 2,
      "text": "Front desk staff was rude and made me wait 30 minutes past my appointment time. Very unprofessional.",
      "author": "Sarah M.",
      "date": "2025-01-15",
      "helpful_count": 8
    },
    {
      "rating": 1,
      "text": "Billing department is a nightmare. They charged my insurance incorrectly and refused to fix it for weeks.",
      "author": "John D.",
      "date": "2025-01-10",
      "helpful_count": 12
    }
  ],
  "total_reviews": 87,
  "average_rating": 4.2
}
```

---

## TEST CASE 1: Happy Path (Austin, TX)

### Test Objective

Validate complete end-to-end workflow with ideal conditions:
- API calls succeed
- Clinics have reviews
- Emails are found and verified
- Pain points are identified
- High-quality leads generated

### Preconditions

- [ ] All services running (n8n, Playwright, Supabase, APIs)
- [ ] Test database is EMPTY (no existing records)
- [ ] API quotas sufficient (100+ requests available)
- [ ] Google Sheets backup sheet is empty

### Input Payload

**HTTP POST to Webhook URL:**
```json
{
  "city": "Austin",
  "state": "TX",
  "count": 10
}
```

### Expected Workflow Behavior

#### Stage 1: Webhook Entry & Validation (Nodes 1-5)

**Node 1: Webhook Entry**
- Receives POST request
- Parses JSON body
- Status: 202 Accepted (async processing)

**Node 2: Set Variables**
```json
{
  "city": "Austin",
  "state": "TX",
  "count": 10,
  "workflow_start_time": "2025-01-20T10:00:00Z"
}
```

**Node 3: Validate Input**
- Checks `city` is not empty
- Checks `state` is valid 2-letter code
- Checks `count` is between 1-100
- Result: VALID ✅

**Node 4: Input Valid? (IF)**
- Condition: All validations pass
- Output: TRUE → Continue to Node 5

**Node 5: Build Search Query**
```json
{
  "search_query": "physical therapy Austin TX",
  "max_results": 10
}
```

#### Stage 2: Google Maps Scraping (Nodes 6-7)

**Node 6: Scrape Google Maps**

*Request to Playwright:*
```json
POST http://localhost:3000/scrape-google-maps
{
  "query": "physical therapy Austin TX",
  "max_results": 10
}
```

*Expected Response (partial):*
```json
{
  "clinics": [
    {
      "place_id": "ChIJ1234567890",
      "name": "Austin Sports Physical Therapy",
      "address": "2001 Guadalupe St, Austin, TX 78705",
      "city": "Austin",
      "state": "TX",
      "zip": "78705",
      "phone": "(512) 474-8888",
      "website": "https://austinsportspt.com",
      "rating": 4.8,
      "total_reviews": 156
    },
    {
      "place_id": "ChIJ0987654321",
      "name": "Central Texas Physical Therapy",
      "address": "3801 N Capital of Texas Hwy, Austin, TX 78746",
      "city": "Austin",
      "state": "TX",
      "zip": "78746",
      "phone": "(512) 327-5433",
      "website": "https://centraltxpt.com",
      "rating": 4.6,
      "total_reviews": 203
    }
  ],
  "total_found": 10,
  "search_query": "physical therapy Austin TX"
}
```

**Verification:**
- Response status: 200
- `clinics` array length: 10
- Each clinic has required fields: `place_id`, `name`, `phone`
- All Austin, TX addresses

**Node 7: Transform Clinic Data**

*Output (per clinic):*
```json
{
  "place_id": "ChIJ1234567890",
  "name": "Austin Sports Physical Therapy",
  "address": "2001 Guadalupe St, Austin, TX 78705",
  "city": "Austin",
  "state": "TX",
  "zip": "78705",
  "phone": "5124748888",
  "phone_valid": true,
  "website": "https://austinsportspt.com",
  "domain": "austinsportspt.com",
  "rating": 4.8,
  "total_reviews": 156
}
```

**Verification:**
- Phone cleaned: No parentheses, spaces, dashes
- Phone valid: 10 digits
- Domain extracted: No "www.", just domain

#### Stage 3: Duplicate Check (Nodes 8a-8b)

**Node 8a: Check for Duplicates**

*Query to Supabase:*
```sql
SELECT * FROM pt_clinic_leads
WHERE place_id = 'ChIJ1234567890'
```

*Expected Response:*
```json
{
  "data": [],
  "count": 0
}
```

**Node 8b: Is New Place ID? (IF)**
- Condition: `data.length === 0`
- Output: TRUE → Continue to Node 10 (all clinics are new)

#### Stage 4: Batch Processing (Node 10)

**Node 10: Split In Batches**
- Total items: 10 clinics
- Batch size: 10
- Batches created: 1
- First batch: All 10 clinics

#### Stage 5: Review Scraping (Nodes 11-13)

**Node 11: Scrape Google Reviews** (for each clinic)

*Request to Playwright (Clinic 1):*
```json
POST http://localhost:3000/scrape-google-reviews
{
  "place_id": "ChIJ1234567890",
  "max_reviews": 50,
  "sort_by": "newest",
  "min_rating": 1,
  "max_rating": 3
}
```

*Expected Response:*
```json
{
  "place_id": "ChIJ1234567890",
  "reviews": [
    {
      "rating": 2,
      "text": "The front desk staff needs serious customer service training. I was treated very rudely when I called to reschedule my appointment. The therapist was great, but the office experience was awful.",
      "author": "Jennifer K.",
      "date": "2025-01-12",
      "helpful_count": 15
    },
    {
      "rating": 3,
      "text": "Long wait times are a consistent problem. I've been here 5 times and never started on time. Always at least 20-30 minutes late.",
      "author": "Michael R.",
      "date": "2025-01-08",
      "helpful_count": 9
    },
    {
      "rating": 2,
      "text": "Billing is a disaster. They charged me for services I didn't receive and it took 6 phone calls to get it resolved.",
      "author": "David L.",
      "date": "2024-12-28",
      "helpful_count": 11
    }
  ],
  "total_reviews": 156,
  "average_rating": 4.8
}
```

**Verification:**
- Response status: 200
- Reviews array has 1-3 star ratings only
- Review text length > 50 characters
- Recent dates (within last 90 days ideal)

**Node 12: Transform Review Data**

*Output:*
```json
{
  "place_id": "ChIJ1234567890",
  "total_reviews": 156,
  "average_rating": 4.8,
  "reviews_analyzed": 3,
  "pain_reviews_found": 3,
  "reviews_for_analysis": [
    {
      "rating": 2,
      "text": "The front desk staff needs serious customer service training...",
      "date": "2025-01-12"
    },
    {
      "rating": 3,
      "text": "Long wait times are a consistent problem...",
      "date": "2025-01-08"
    },
    {
      "rating": 2,
      "text": "Billing is a disaster...",
      "date": "2024-12-28"
    }
  ],
  "scrape_timestamp": "2025-01-20T10:05:30Z"
}
```

**Node 13: Has Pain Reviews? (IF)**
- Condition: `pain_reviews_found >= 1`
- Output: TRUE → Continue to email enrichment

#### Stage 6: Email Enrichment (Nodes 15-20)

**Node 15: Scrape Website for Emails**

*Request to Playwright:*
```json
POST http://localhost:3000/scrape-website-emails
{
  "url": "https://austinsportspt.com",
  "pages_to_check": ["contact", "about", "team", "staff"],
  "max_pages": 4
}
```

*Expected Response:*
```json
{
  "url": "https://austinsportspt.com",
  "emails_found": [
    "michael.thompson@austinsportspt.com",
    "info@austinsportspt.com",
    "frontdesk@austinsportspt.com"
  ],
  "pages_checked": ["/contact", "/about"],
  "success": true
}
```

**Node 16: Prioritize Emails**

*Output:*
```json
{
  "prioritized_emails": [
    {"email": "michael.thompson@austinsportspt.com", "score": 85, "source": "website_scrape"},
    {"email": "info@austinsportspt.com", "score": 60, "source": "website_scrape"},
    {"email": "frontdesk@austinsportspt.com", "score": 55, "source": "website_scrape"}
  ],
  "primary_email": "michael.thompson@austinsportspt.com",
  "email_confidence": 85
}
```

**Node 17: Email Found from Website? (IF)**
- Condition: `primary_email !== '' AND email_confidence >= 50`
- Output: TRUE → Skip to email verification (Node 22)

#### Stage 7: Email Verification (Nodes 22-27)

**Node 22: Prepare Emails for Verification**

*Output:*
```json
{
  "emails_to_verify": [
    {"email": "michael.thompson@austinsportspt.com", "score": 85}
  ],
  "total_candidates": 3,
  "unique_candidates": 3
}
```

**Node 23: Split Emails for Verification**
- Takes top 5 emails (in this case, 1 email)
- Creates 1 separate item

**Node 24: Verify Email with ZeroBounce**

*Request to ZeroBounce:*
```
GET https://api.zerobounce.net/v2/validate?api_key=XXX&email=michael.thompson@austinsportspt.com
```

*Expected Response:*
```json
{
  "email": "michael.thompson@austinsportspt.com",
  "status": "valid",
  "sub_status": "mailbox_found",
  "free_email": false,
  "smtp_provider": "google",
  "mx_found": "true",
  "mx_record": "aspmx.l.google.com",
  "did_you_mean": null
}
```

**Node 25: Filter Valid Emails**
- Condition: `status === 'valid' OR status === 'catch-all'`
- Output: Email passes filter ✅

**Node 26: Aggregate Valid Emails**

*Output (grouped by place_id):*
```json
{
  "place_id": "ChIJ1234567890",
  "verified_emails": ["michael.thompson@austinsportspt.com"],
  "email_scores": [85]
}
```

**Node 27: Select Primary Email**

*Output:*
```json
{
  "place_id": "ChIJ1234567890",
  "name": "Austin Sports Physical Therapy",
  "primary_email": "michael.thompson@austinsportspt.com",
  "backup_emails": [],
  "email_found": true,
  "total_verified_emails": 1,
  // ... other clinic data
}
```

#### Stage 8: Pain Analysis with Claude (Nodes 28-30)

**Node 28: Has Pain Reviews? (IF)**
- Condition: `skip_pain_analysis !== true AND pain_reviews_found >= 1`
- Output: TRUE → Call Claude API

**Node 29: Analyze Pain Points with Claude**

*Request to Claude API:*
```json
POST https://api.anthropic.com/v1/messages
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 2000,
  "temperature": 0.3,
  "messages": [
    {
      "role": "user",
      "content": "You are analyzing patient reviews for a physical therapy clinic...\n\nClinic: Austin Sports Physical Therapy\nLocation: Austin, TX\n\nReviews to analyze:\n[2★] The front desk staff needs serious customer service training...\n[3★] Long wait times are a consistent problem...\n[2★] Billing is a disaster...\n\nTask: Identify top 3 pain point categories..."
    }
  ]
}
```

*Expected Response:*
```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"pain_categories\":[{\"category\":\"Front Desk Service\",\"severity\":\"High\",\"frequency\":1,\"evidence_quote\":\"The front desk staff needs serious customer service training. I was treated very rudely when I called to reschedule my appointment.\",\"suggested_solution\":\"Implement comprehensive customer service training program for front desk staff and establish patient communication protocols\"},{\"category\":\"Wait Times\",\"severity\":\"Medium\",\"frequency\":1,\"evidence_quote\":\"Long wait times are a consistent problem. I've been here 5 times and never started on time. Always at least 20-30 minutes late.\",\"suggested_solution\":\"Optimize scheduling system to reduce overbooking and implement patient flow management system\"},{\"category\":\"Billing Issues\",\"severity\":\"High\",\"frequency\":1,\"evidence_quote\":\"Billing is a disaster. They charged me for services I didn't receive and it took 6 phone calls to get it resolved.\",\"suggested_solution\":\"Overhaul billing verification process and provide staff training on insurance coding accuracy\"}],\"overall_sentiment\":\"Negative\",\"primary_pain_point\":\"Front Desk Service\"}"
    }
  ],
  "usage": {
    "input_tokens": 456,
    "output_tokens": 218
  }
}
```

**Node 30: Parse Claude Response**

*Output:*
```json
{
  "place_id": "ChIJ1234567890",
  "name": "Austin Sports Physical Therapy",
  "primary_email": "michael.thompson@austinsportspt.com",
  "pain_categories": [
    {
      "category": "Front Desk Service",
      "severity": "High",
      "frequency": 1,
      "evidence_quote": "The front desk staff needs serious customer service training...",
      "suggested_solution": "Implement comprehensive customer service training program..."
    },
    {
      "category": "Wait Times",
      "severity": "Medium",
      "frequency": 1,
      "evidence_quote": "Long wait times are a consistent problem...",
      "suggested_solution": "Optimize scheduling system to reduce overbooking..."
    },
    {
      "category": "Billing Issues",
      "severity": "High",
      "frequency": 1,
      "evidence_quote": "Billing is a disaster...",
      "suggested_solution": "Overhaul billing verification process..."
    }
  ],
  "primary_pain_point": "Front Desk Service",
  "overall_sentiment": "Negative",
  "pain_analysis_complete": true,
  "claude_tokens_used": 674
}
```

#### Stage 9: Lead Scoring (Nodes 32-33)

**Node 32: Calculate Lead Score**

*Scoring Calculation:*
```javascript
// FACTOR 1: Email Quality (85 confidence) = 30 points
score += 30;

// FACTOR 2: Pain Point Severity
// 2 High severity pains = 2 * 15 = 30 points
// 1 Medium severity pain = 1 * 8 = 8 points
score += 38;

// FACTOR 3: Review Volume (156 reviews >= 100) = 15 points
score += 15;

// FACTOR 4: Phone Valid = 10 points
score += 10;

// FACTOR 5: Website = 5 points
score += 5;

// TOTAL = 30 + 38 + 15 + 10 + 5 = 98 points
```

*Output:*
```json
{
  "place_id": "ChIJ1234567890",
  "name": "Austin Sports Physical Therapy",
  "lead_score": 98,
  "tier": "A",
  "score_timestamp": "2025-01-20T10:08:15Z",
  // ... all other clinic data
}
```

**Node 33: Filter High-Value Leads**
- Condition: `lead_score >= 50`
- Output: Passes filter (98 >= 50) ✅

#### Stage 10: Database Storage (Nodes 34-36)

**Node 34: Prepare Supabase Record**

*Output (formatted for Supabase):*
```json
{
  "place_id": "ChIJ1234567890",
  "name": "Austin Sports Physical Therapy",
  "address": "2001 Guadalupe St, Austin, TX 78705",
  "city": "Austin",
  "state": "TX",
  "zip": "78705",
  "phone": "5124748888",
  "phone_valid": true,
  "website": "https://austinsportspt.com",
  "domain": "austinsportspt.com",
  "primary_email": "michael.thompson@austinsportspt.com",
  "backup_emails": [],
  "email_confidence": 85,
  "total_reviews": 156,
  "average_rating": 4.8,
  "reviews_analyzed": 3,
  "pain_categories": [
    {
      "category": "Front Desk Service",
      "severity": "High",
      "frequency": 1,
      "evidence_quote": "The front desk staff needs serious customer service training...",
      "suggested_solution": "Implement comprehensive customer service training program..."
    },
    {
      "category": "Wait Times",
      "severity": "Medium",
      "frequency": 1,
      "evidence_quote": "Long wait times are a consistent problem...",
      "suggested_solution": "Optimize scheduling system..."
    },
    {
      "category": "Billing Issues",
      "severity": "High",
      "frequency": 1,
      "evidence_quote": "Billing is a disaster...",
      "suggested_solution": "Overhaul billing verification process..."
    }
  ],
  "primary_pain_point": "Front Desk Service",
  "overall_sentiment": "Negative",
  "lead_score": 98,
  "tier": "A",
  "status": "new",
  "discovery_count": 1,
  "last_seen": "2025-01-20T10:08:20Z",
  "created_at": "2025-01-20T10:08:20Z"
}
```

**Node 35: Insert into Supabase**

*Request:*
```sql
POST https://test-project.supabase.co/rest/v1/pt_clinic_leads
Content-Type: application/json
apikey: eyJhbGc...TEST_KEY
Authorization: Bearer eyJhbGc...TEST_KEY
Prefer: return=representation

{... (data from Node 34)}
```

*Expected Response:*
```json
{
  "id": 1,
  "place_id": "ChIJ1234567890",
  "name": "Austin Sports Physical Therapy",
  "primary_email": "michael.thompson@austinsportspt.com",
  "lead_score": 98,
  "tier": "A",
  "status": "new",
  "created_at": "2025-01-20T10:08:21Z"
  // ... all fields
}
```

**Verification Query:**
```sql
SELECT COUNT(*) FROM pt_clinic_leads WHERE place_id = 'ChIJ1234567890';
-- Expected: 1

SELECT tier, lead_score FROM pt_clinic_leads WHERE place_id = 'ChIJ1234567890';
-- Expected: tier='A', lead_score=98
```

**Node 36: Backup to Google Sheets**

*Operation:* appendOrUpdate to Google Sheet
*Expected:* New row added with key fields

**Verification:**
- Open Google Sheet
- Check last row contains "Austin Sports Physical Therapy"
- Verify lead_score = 98, tier = A

#### Stage 11: Email Generation (Nodes 37-39)

**Node 37: Generate Outreach Email with Claude**

*Request to Claude API:*
```json
POST https://api.anthropic.com/v1/messages
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 1500,
  "temperature": 0.7,
  "messages": [
    {
      "role": "user",
      "content": "You are writing a personalized cold outreach email...\n\nTARGET CLINIC:\nName: Austin Sports Physical Therapy\nLocation: Austin, TX\nOwner: Clinic Owner\n\nPAIN POINTS IDENTIFIED:\n- Front Desk Service (High severity): \"The front desk staff needs serious customer service training...\"\n- Wait Times (Medium severity): \"Long wait times are a consistent problem...\"\n- Billing Issues (High severity): \"Billing is a disaster...\"\n\n..."
    }
  ]
}
```

*Expected Response:*
```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"subject\":\"Quick thought on Austin Sports PT's front desk feedback\",\"body\":\"Hi Michael,\\n\\nI came across Austin Sports PT while researching physical therapy practices in Austin. I noticed several recent reviews highlighting front desk service challenges — one patient specifically mentioned, \\\"The front desk staff needs serious customer service training.\\\"\\n\\nWe specialize in helping PT clinics improve patient experience and acquisition. We recently helped South Austin PT reduce patient complaints by 67% and increase their Google rating from 4.2 to 4.9 stars through staff training and patient communication systems.\\n\\nWould a 15-minute call make sense to discuss how we might help Austin Sports PT achieve similar improvements?\\n\\nBest,\\nSarah Chen\\nClinicGrowthLab\\n(555) 123-4567\"}"
    }
  ]
}
```

**Node 38: Parse Email Content**

*Output:*
```json
{
  "place_id": "ChIJ1234567890",
  "email_subject": "Quick thought on Austin Sports PT's front desk feedback",
  "email_body": "Hi Michael,\n\nI came across Austin Sports PT while researching physical therapy practices in Austin. I noticed several recent reviews highlighting front desk service challenges — one patient specifically mentioned, \"The front desk staff needs serious customer service training.\"\n\nWe specialize in helping PT clinics improve patient experience and acquisition. We recently helped South Austin PT reduce patient complaints by 67% and increase their Google rating from 4.2 to 4.9 stars through staff training and patient communication systems.\n\nWould a 15-minute call make sense to discuss how we might help Austin Sports PT achieve similar improvements?\n\nBest,\nSarah Chen\nClinicGrowthLab\n(555) 123-4567",
  "email_generated": true,
  "email_generation_timestamp": "2025-01-20T10:09:45Z"
}
```

**Node 39: Update Supabase with Email**

*Request:*
```sql
PATCH https://test-project.supabase.co/rest/v1/pt_clinic_leads?place_id=eq.ChIJ1234567890
{
  "email_subject": "Quick thought on Austin Sports PT's front desk feedback",
  "email_body": "Hi Michael...",
  "email_generated_at": "2025-01-20T10:09:45Z",
  "status": "ready_to_send",
  "updated_at": "2025-01-20T10:09:45Z"
}
```

**Verification Query:**
```sql
SELECT status, email_subject FROM pt_clinic_leads
WHERE place_id = 'ChIJ1234567890';
-- Expected: status='ready_to_send', email_subject='Quick thought on Austin Sports PT...'
```

#### Stage 12: Workflow Completion (Nodes 40-44)

**Node 40: More Batches Remaining? (IF)**
- Check: `$('Split In Batches').context.noItemsLeft`
- Result: FALSE (all 10 clinics processed in 1 batch)
- Output: Continue to summary

**Node 41: Aggregate Results**

*Output (collected from all 10 clinics):*
```json
{
  "all_scores": [98, 87, 92, 76, 68, 81, 73, 55, 89, 91],
  "all_tiers": ["A", "A", "A", "A", "B", "A", "A", "B", "A", "A"],
  "all_place_ids": ["ChIJ1234567890", "ChIJ0987654321", ...]
}
```

**Node 42: Calculate Summary Statistics**

*Output:*
```json
{
  "total_leads": 10,
  "average_score": 81,
  "tier_a_count": 8,
  "tier_b_count": 2,
  "tier_c_count": 0,
  "top_score": 98,
  "low_score": 55,
  "summary_message": "🎯 PT Clinic Lead Discovery Complete\n\nTotal Leads Processed: 10\nAverage Lead Score: 81/100\n\nTier Breakdown:\n• Tier A (High-Value): 8 leads\n• Tier B (Medium-Value): 2 leads\n• Tier C (Low-Value): 0 leads\n\nScore Range: 55 - 98\n\nAll leads have been:\n✅ Stored in Supabase\n✅ Backed up to Google Sheets\n✅ Personalized emails generated\n✅ Ready for outreach\n\nNext Step: Review Tier A leads in dashboard",
  "workflow_timestamp": "2025-01-20T10:12:00Z"
}
```

**Node 43: Send Gmail Notification**

*Email Sent:*
```
To: test@example.com
Subject: PT Lead Discovery Complete: 10 New Leads (8 Tier A)

Body:
🎯 PT Clinic Lead Discovery Complete

Total Leads Processed: 10
Average Lead Score: 81/100

Tier Breakdown:
• Tier A (High-Value): 8 leads
• Tier B (Medium-Value): 2 leads
• Tier C (Low-Value): 0 leads

Score Range: 55 - 98

All leads have been:
✅ Stored in Supabase
✅ Backed up to Google Sheets
✅ Personalized emails generated
✅ Ready for outreach

Next Step: Review Tier A leads in dashboard
```

**Node 44: Webhook Response**

*HTTP Response to original webhook caller:*
```json
HTTP/1.1 200 OK
Content-Type: application/json

{
  "success": true,
  "message": "Lead discovery workflow completed",
  "total_leads_processed": 10,
  "tier_a_leads": 8,
  "tier_b_leads": 2,
  "average_score": 81,
  "workflow_duration_seconds": 720,
  "timestamp": "2025-01-20T10:12:00Z"
}
```

### Success Criteria

**Must Pass All:**

1. ✅ All 10 clinics discovered via Google Maps scraping
2. ✅ All 10 clinics are new (not duplicates)
3. ✅ At least 8/10 clinics have reviews scraped
4. ✅ At least 7/10 clinics have verified emails
5. ✅ At least 6/10 clinics have pain analysis completed
6. ✅ All clinics have lead scores calculated (0-100)
7. ✅ At least 6/10 clinics are Tier A or B (score >= 50)
8. ✅ All high-value leads stored in Supabase
9. ✅ All high-value leads backed up to Google Sheets
10. ✅ All high-value leads have personalized emails generated
11. ✅ Workflow completes without errors
12. ✅ Completion time < 15 minutes (90 seconds per clinic average)
13. ✅ Summary email received within 1 minute of completion
14. ✅ Webhook returns 200 OK with summary JSON

### Verification Queries

Run these queries to validate test results:

```sql
-- Check total records created
SELECT COUNT(*) as total_leads FROM pt_clinic_leads;
-- Expected: 10

-- Check tier distribution
SELECT tier, COUNT(*) as count
FROM pt_clinic_leads
GROUP BY tier
ORDER BY tier;
-- Expected: A=8, B=2

-- Check email generation
SELECT COUNT(*) as emails_generated
FROM pt_clinic_leads
WHERE email_subject IS NOT NULL;
-- Expected: 10

-- Check pain analysis
SELECT COUNT(*) as pain_analyzed
FROM pt_clinic_leads
WHERE pain_categories != '[]'::jsonb;
-- Expected: >= 7

-- Check status
SELECT status, COUNT(*) as count
FROM pt_clinic_leads
GROUP BY status;
-- Expected: ready_to_send=10

-- Top 3 highest scoring leads
SELECT name, lead_score, tier, primary_pain_point
FROM pt_clinic_leads
ORDER BY lead_score DESC
LIMIT 3;
-- Expected: Scores 90-98, Tier A, pain points identified
```

### Edge Cases Covered

- ✅ Clinic with 150+ reviews (high volume)
- ✅ Clinic with 10-50 reviews (medium volume)
- ✅ Clinic with excellent rating (4.5+) but still has negative reviews
- ✅ Multiple pain categories identified (3 pain points)
- ✅ Personal email found on website (firstname.lastname@domain)
- ✅ Generic email found (info@domain) with lower confidence
- ✅ Phone number with various formats: (512) 474-8888, 512-474-8888, 5124748888

---


## TEST CASE 2: Small City - Limited Results

### Test Objective

Validate workflow behavior when Google Maps returns fewer results than requested, simulating a small city with limited PT clinics.

### Preconditions

- [ ] All services running
- [ ] Test database is empty
- [ ] API quotas sufficient

### Input Payload

```json
{
  "city": "Abilene",
  "state": "TX",
  "count": 20
}
```

### Expected Behavior

**Node 6: Scrape Google Maps**
- Request: 20 clinics
- Actual Results: Only 8 clinics found (Abilene is small city)

*Expected Response:*
```json
{
  "clinics": [
    // ... 8 clinics only
  ],
  "total_found": 8,
  "search_query": "physical therapy Abilene TX",
  "note": "Fewer results than requested"
}
```

**Node 10: Split In Batches**
- Total items: 8 (not 20)
- Batch size: 10
- Batches: 1 batch with 8 items

**Workflow Completion:**
- Processes all 8 clinics successfully
- No errors due to low count
- Summary shows "Total Leads Processed: 8"

### Success Criteria

1. ✅ Workflow adapts to fewer results without error
2. ✅ All 8 clinics processed completely
3. ✅ No timeout or retry issues
4. ✅ Summary email correctly reports 8 leads (not 20)
5. ✅ Webhook response: `total_leads_processed: 8`

### Verification Query

```sql
SELECT COUNT(*) FROM pt_clinic_leads WHERE city = 'Abilene';
-- Expected: 8

SELECT city, COUNT(*) as count FROM pt_clinic_leads GROUP BY city;
-- Expected: Abilene = 8 (no other cities)
```

### Edge Cases Covered

- ✅ Requested count > available clinics
- ✅ Batch processing with less than batch size
- ✅ Summary statistics with small dataset

---

## TEST CASE 3: Scraping Blocked by Anti-Bot

### Test Objective

Validate error handling when Playwright scraping is blocked by Cloudflare, rate limiting, or anti-bot measures.

### Preconditions

- [ ] All services running
- [ ] Simulate blocking by:
  - Option A: Rate-limit Playwright container (make 50+ requests rapidly before test)
  - Option B: Use domain known to block scraping
  - Option C: Modify Playwright to return 429 status

### Input Payload

```json
{
  "city": "Dallas",
  "state": "TX",
  "count": 10
}
```

### Simulated Error

**Node 6: Scrape Google Maps** throws error:
```json
{
  "error": "Request blocked",
  "status": 429,
  "message": "Too many requests. Rate limit exceeded.",
  "retry_after": 60
}
```

### Expected Behavior

**Error Handling Flow:**

1. **Node 45: Error Trigger** catches error
2. **Node 46: Categorize Error**
```json
{
  "error_category": "rate_limit",
  "error_message": "Too many requests. Rate limit exceeded.",
  "failed_node": "Scrape Google Maps",
  "should_retry": true,
  "recommended_action": "wait_and_retry"
}
```

3. **Node 47: Should Retry? (IF)** → TRUE

4. **Node 48: Wait 30 Seconds** (pause execution)

5. **Node 49: Retry Failed Operation**
   - Retry attempt = 1
   - Same input data

6. **Second Attempt:**
   - If success → Continue workflow
   - If still blocked → Retry once more (n8n native retry in Node 6 settings)
   - If blocked after 2 retries → Error logged

7. **If All Retries Fail:**
   - **Node 50: Log Error to Supabase**
   - **Node 51: Send Error Alert Email**
   - **Node 52: Circuit Breaker Check**
     - First failure: circuit_breaker_triggered = false, continue
     - 5th consecutive failure: circuit_breaker_triggered = true

### Success Criteria

1. ✅ Error is caught and categorized correctly
2. ✅ Workflow waits 30 seconds before retry
3. ✅ Retry is attempted with same data
4. ✅ If retry succeeds, workflow continues normally
5. ✅ If retry fails, error is logged to `workflow_errors` table
6. ✅ Admin receives error alert email
7. ✅ Circuit breaker activates after 5 consecutive failures
8. ✅ Workflow does NOT crash or hang

### Verification Queries

```sql
-- Check error log
SELECT * FROM workflow_errors
WHERE error_category = 'rate_limit'
ORDER BY timestamp DESC
LIMIT 5;
-- Expected: 1-3 entries depending on retry success

-- Check if any leads were processed before error
SELECT COUNT(*) FROM pt_clinic_leads WHERE city = 'Dallas';
-- Expected: 0 if error occurred at Node 6, or partial count if later stage
```

### Edge Cases Covered

- ✅ Rate limiting (429 status)
- ✅ Retry logic with exponential backoff
- ✅ Circuit breaker after repeated failures
- ✅ Error logging and alerting
- ✅ Graceful degradation (workflow doesn't crash)

---

## TEST CASE 4: Supabase Database Down

### Test Objective

Validate zero data loss architecture when primary database (Supabase) is unavailable. Workflow should fallback to Google Sheets and send emergency notification.

### Preconditions

- [ ] All services running
- [ ] Simulate Supabase outage by:
  - Option A: Change `SUPABASE_URL` to invalid URL
  - Option B: Revoke `SUPABASE_ANON_KEY` temporarily
  - Option C: Use firewall to block Supabase domain

### Input Payload

```json
{
  "city": "Houston",
  "state": "TX",
  "count": 5
}
```

### Simulated Error

**Node 35: Insert into Supabase** throws error:
```json
{
  "error": "Database connection failed",
  "status": 503,
  "message": "Service temporarily unavailable"
}
```

### Expected Behavior

1. **Scraping Succeeds:** Nodes 1-34 complete successfully (5 clinics processed)

2. **Node 35: Insert into Supabase** fails

3. **Node 45: Error Trigger** catches database error

4. **Node 46: Categorize Error**
```json
{
  "error_category": "database",
  "error_message": "Service temporarily unavailable",
  "failed_node": "Insert into Supabase",
  "should_retry": true,
  "recommended_action": "use_backup_storage"
}
```

5. **Node 47: Should Retry?** → TRUE

6. **Node 48-49: Wait and Retry**
   - Waits 30 seconds
   - Retries Supabase insert
   - Still fails (database down)

7. **Fallback to Backup:**
   - **Node 36: Backup to Google Sheets** should still execute
   - All 5 clinic records written to Google Sheets
   - NO DATA LOSS ✅

8. **Node 51: Send Error Alert Email**
```
Subject: 🚨 PT Workflow Error: database in Insert into Supabase

Error Details:

Category: database
Node: Insert into Supabase
Message: Service temporarily unavailable

Recommended Action: use_backup_storage

⚠️ Data has been backed up to Google Sheets.
Please restore Supabase and manually sync data.
```

### Success Criteria

1. ✅ Workflow does NOT lose any clinic data
2. ✅ All 5 clinics backed up to Google Sheets
3. ✅ Error logged to... wait, can't log to Supabase if it's down!
   - Error logging should also fail gracefully
4. ✅ Admin receives critical alert email
5. ✅ Webhook response indicates partial success:
```json
{
  "success": false,
  "message": "Primary database unavailable. Data backed up to Google Sheets.",
  "leads_processed": 5,
  "backup_location": "Google Sheets",
  "error": "Supabase connection failed"
}
```

### Verification Steps

1. **Check Google Sheets:**
   - Open backup spreadsheet
   - Verify 5 new rows added
   - Verify all key fields populated: name, email, lead_score, pain_points

2. **Check Email:**
   - Admin received critical alert
   - Subject mentions "database" error

3. **Check Supabase (after restoring):**
   ```sql
   SELECT COUNT(*) FROM pt_clinic_leads WHERE city = 'Houston';
   -- Expected: 0 (database was down during test)
   ```

4. **Manual Data Recovery:**
   - Export data from Google Sheets
   - Import into Supabase using bulk insert
   - Verify no duplicates (use place_id uniqueness)

### Edge Cases Covered

- ✅ Primary database failure
- ✅ Automatic fallback to secondary storage
- ✅ Zero data loss architecture
- ✅ Error notification without database logging
- ✅ Manual recovery process

---

## TEST CASE 5: Claude API Rate Limit

### Test Objective

Validate workflow behavior when Claude API hits rate limits during pain analysis or email generation.

### Preconditions

- [ ] All services running
- [ ] Use Claude API key with low rate limit (e.g., free tier)
- [ ] OR make 50+ Claude API calls before test to exhaust quota

### Input Payload

```json
{
  "city": "San Antonio",
  "state": "TX",
  "count": 15
}
```

### Simulated Error

**Node 29: Analyze Pain Points with Claude** throws error after processing 3 clinics:
```json
{
  "error": {
    "type": "rate_limit_error",
    "message": "Your API key has exceeded the rate limit. Please try again later."
  },
  "status": 429
}
```

### Expected Behavior

**First 3 Clinics:**
- Process successfully with pain analysis ✅
- Lead scores calculated with pain points
- Emails generated

**Clinic 4 (Rate Limit Hit):**

1. **Node 29: Claude API** returns 429 error

2. **Node 45: Error Trigger** catches rate limit

3. **Node 46: Categorize Error**
```json
{
  "error_category": "rate_limit",
  "error_message": "API key exceeded rate limit",
  "failed_node": "Analyze Pain Points with Claude",
  "should_retry": true,
  "recommended_action": "wait_and_retry"
}
```

4. **Node 48: Wait 30 Seconds**

5. **Retry:** Still fails (rate limit not reset in 30s)

6. **Fallback Behavior:**
   - Skip pain analysis for remaining 12 clinics
   - Set `skip_pain_analysis = true`
   - Assign `tier = 'C'` (no pain data = lower quality)
   - Continue with email enrichment

**Remaining 12 Clinics:**
- NO pain analysis (Claude skipped)
- Emails still found and verified
- Lead scores calculated WITHOUT pain factor (max 60 points instead of 100)
- Tier B/C leads (lower quality)

**Email Generation (Node 37):**
- Also uses Claude API → May also hit rate limit
- Fallback: Use generic email template (from Node 38 error handling)

### Success Criteria

1. ✅ First 3 clinics processed with full pain analysis
2. ✅ Rate limit error caught and logged
3. ✅ Workflow adapts by skipping Claude for remaining clinics
4. ✅ All 15 clinics still processed (no data loss)
5. ✅ Lead scores reflect missing pain data (lower scores)
6. ✅ Generic emails used as fallback
7. ✅ Admin receives alert about API quota
8. ✅ Summary email indicates partial pain analysis:
```
Total Leads: 15
- With Pain Analysis: 3
- Without Pain Analysis: 12
Average Score: 58 (lower due to missing pain data)
```

### Verification Queries

```sql
-- Check pain analysis completion
SELECT
  COUNT(*) as total,
  SUM(CASE WHEN pain_categories != '[]'::jsonb THEN 1 ELSE 0 END) as with_pain,
  SUM(CASE WHEN pain_categories = '[]'::jsonb THEN 1 ELSE 0 END) as without_pain
FROM pt_clinic_leads
WHERE city = 'San Antonio';
-- Expected: total=15, with_pain=3, without_pain=12

-- Check tier distribution (should have more Tier C)
SELECT tier, COUNT(*) FROM pt_clinic_leads
WHERE city = 'San Antonio'
GROUP BY tier;
-- Expected: More Tier C than usual (no pain data = lower scores)

-- Check error log
SELECT * FROM workflow_errors
WHERE error_category = 'rate_limit'
  AND failed_node = 'Analyze Pain Points with Claude'
ORDER BY timestamp DESC;
-- Expected: 1 error logged
```

### Edge Cases Covered

- ✅ Claude API rate limiting
- ✅ Partial workflow success (some items processed, others skipped)
- ✅ Graceful degradation (continue without AI analysis)
- ✅ Fallback to generic email templates
- ✅ Lead scoring without pain analysis data

---

## TEST CASE 6: Clinics with Zero Reviews

### Test Objective

Validate workflow correctly handles new/small clinics that have no Google Reviews, skipping pain analysis but still enriching contacts.

### Preconditions

- [ ] All services running
- [ ] Target new clinics or very small practices

### Input Payload

```json
{
  "city": "Round Rock",
  "state": "TX",
  "count": 10
}
```

### Expected Behavior

**Node 11: Scrape Google Reviews** returns:
```json
{
  "place_id": "ChIJNewClinic123",
  "reviews": [],
  "total_reviews": 0,
  "average_rating": null
}
```

**Node 12: Transform Review Data**
```json
{
  "place_id": "ChIJNewClinic123",
  "total_reviews": 0,
  "reviews_analyzed": 0,
  "pain_reviews_found": 0,
  "reviews_for_analysis": []
}
```

**Node 13: Has Pain Reviews? (IF)**
- Condition: `pain_reviews_found >= 1`
- Result: FALSE

**Node 14: Mark No Reviews**
```json
{
  "place_id": "ChIJNewClinic123",
  "has_reviews": false,
  "pain_categories": [],
  "skip_pain_analysis": true,
  "tier": "C"
}
```

**Workflow Continues:**
- Email enrichment still happens (Nodes 15-27)
- Pain analysis SKIPPED (Node 28 → FALSE branch)
- Lead scoring WITHOUT pain factor (max 60 points)
- Email generation uses GENERIC template (no specific pain points to reference)

**Node 37: Generate Email (No Pain Data)**

*Claude Prompt Includes:*
```
PAIN POINTS IDENTIFIED FROM REVIEWS:
(No reviews available)
```

*Expected Email:*
```
Subject: Helping Round Rock PT clinics grow patient base

Hi,

I came across your practice while researching physical therapy clinics in Round Rock. I noticed you're building your online presence — we specialize in helping new PT clinics accelerate patient acquisition and establish strong reputations.

We recently helped a similar practice in Georgetown go from 12 patients/week to 35 patients/week in 90 days through targeted local SEO and Google Ads.

Would a quick call make sense to explore if we can help you achieve similar growth?

Best,
Sarah Chen
ClinicGrowthLab
```

### Success Criteria

1. ✅ All 10 clinics processed without errors
2. ✅ All clinics correctly marked with `has_reviews = false`
3. ✅ Pain analysis skipped for all (saves Claude API costs)
4. ✅ Emails still enriched and verified
5. ✅ Lead scores calculated (range: 15-60 points)
6. ✅ All clinics assigned Tier C (appropriate for no review data)
7. ✅ Generic emails generated (no pain point references)
8. ✅ Workflow completes in ~8 minutes (faster without Claude pain analysis)

### Verification Queries

```sql
-- Check all have no reviews
SELECT COUNT(*) FROM pt_clinic_leads
WHERE city = 'Round Rock' AND total_reviews = 0;
-- Expected: 10

-- Check all have empty pain categories
SELECT COUNT(*) FROM pt_clinic_leads
WHERE city = 'Round Rock'
  AND pain_categories = '[]'::jsonb;
-- Expected: 10

-- Check all Tier C
SELECT tier, COUNT(*) FROM pt_clinic_leads
WHERE city = 'Round Rock'
GROUP BY tier;
-- Expected: C = 10

-- Check emails still generated
SELECT COUNT(*) FROM pt_clinic_leads
WHERE city = 'Round Rock'
  AND email_subject IS NOT NULL;
-- Expected: 10

-- Check generic email content (no specific pain mentions)
SELECT email_body FROM pt_clinic_leads
WHERE city = 'Round Rock'
LIMIT 1;
-- Verify: No phrases like "I noticed your reviews mention..." or specific pain quotes
```

### Edge Cases Covered

- ✅ Zero reviews (new clinic)
- ✅ Null average rating
- ✅ Pain analysis skipped correctly
- ✅ Generic email generation
- ✅ Appropriate tier assignment (Tier C)
- ✅ Cost optimization (no unnecessary Claude API calls)

---

## TEST CASE 7: All Email Verification Failures

### Test Objective

Validate workflow behavior when email verification fails for all generated patterns (no valid emails found).

### Preconditions

- [ ] All services running
- [ ] Use clinics with no website OR broken website links
- [ ] OR temporarily set ZeroBounce API to reject all emails (for testing)

### Input Payload

```json
{
  "city": "Killeen",
  "state": "TX",
  "count": 5
}
```

### Expected Behavior

**Node 15: Scrape Website for Emails**
- Clinic has no website OR website scraping fails
- Result: `emails_found = []`

**Node 17: Email Found from Website? (IF)**
- Result: FALSE → Generate patterns

**Node 18-20: Generate Email Patterns**
```json
{
  "generated_emails": [
    {"email": "info@killeeenpt.com", "score": 60},
    {"email": "contact@killeenpt.com", "score": 60},
    {"email": "admin@killeenpt.com", "score": 55}
  ]
}
```

**Node 24: Verify Email with ZeroBounce**

*All patterns return INVALID:*
```json
{
  "email": "info@killeenpt.com",
  "status": "invalid",
  "sub_status": "mailbox_not_found"
}
```

**Node 25: Filter Valid Emails**
- Filters out all invalid emails
- Result: Empty array `[]`

**Node 26: Aggregate Valid Emails**
- No valid emails to aggregate
- Result: `verified_emails = []`

**Node 27: Select Primary Email**
```json
{
  "primary_email": null,
  "backup_emails": [],
  "email_found": false
}
```

**Node 33: Filter High-Value Leads**
- Condition: `lead_score >= 50`
- Without valid email, scoring calculation:
  - Email factor: 0 points (no email)
  - Pain factor: up to 40 points
  - Review volume: up to 15 points
  - Phone: 10 points
  - Website: 5 points
  - **Max possible: 70 points**

**Result:**
- If clinic has strong pain points + reviews: May still pass filter (score 50-70)
- If clinic lacks pain data: Score < 50, filtered out

**Clinics WITH strong data but NO email:**
- Stored in database with `primary_email = null`
- Status = 'new' (not 'ready_to_send')
- Email generation skipped (Node 37 condition should check for email)

### Success Criteria

1. ✅ Workflow processes all 5 clinics without crashing
2. ✅ All email verification attempts are made
3. ✅ Invalid emails correctly filtered out
4. ✅ Clinics WITHOUT valid email are either:
   - Filtered out if low score (< 50), OR
   - Stored with `primary_email = null` if high pain/review score
5. ✅ Email generation skipped for clinics without email
6. ✅ Summary reports accurate count:
```
Total Leads: 2 (3 filtered out for no email + low score)
Emails Found: 0
Ready to Send: 0
```

### Verification Queries

```sql
-- Check how many stored vs filtered
SELECT COUNT(*) FROM pt_clinic_leads WHERE city = 'Killeen';
-- Expected: 0-5 depending on pain/review scores

-- Check all have null email
SELECT primary_email, COUNT(*) FROM pt_clinic_leads
WHERE city = 'Killeen'
GROUP BY primary_email;
-- Expected: NULL = all records

-- Check status (should NOT be 'ready_to_send' without email)
SELECT status FROM pt_clinic_leads WHERE city = 'Killeen';
-- Expected: 'new' (not ready to send without email)

-- Check email_subject is null (no email generated)
SELECT email_subject FROM pt_clinic_leads WHERE city = 'Killeen';
-- Expected: NULL for all
```

### Edge Cases Covered

- ✅ Website scraping returns no emails
- ✅ Generated email patterns all invalid
- ✅ Email verification complete failure
- ✅ Lead scoring without email factor
- ✅ Filtering logic when no contactable email
- ✅ Email generation conditional on having valid email
- ✅ Leads stored for future manual enrichment

---

## TEST CASE 8: Stress Test (100 Clinics)

### Test Objective

Validate workflow performance, scalability, and stability under high volume. Test batch processing, resource management, and completion time.

### Preconditions

- [ ] All services running on production-like infrastructure
- [ ] API quotas sufficient for 100 clinics:
  - Google Maps: 100 requests
  - Google Reviews: 100 requests
  - Website scraping: 100 requests
  - ZeroBounce: ~200 verifications (2 per clinic avg)
  - Claude API: ~100 pain analyses + 100 email generations = 200 requests
- [ ] Test database is empty
- [ ] Monitor system resources (CPU, RAM, network)

### Input Payload

```json
{
  "city": "Phoenix",
  "state": "AZ",
  "count": 100
}
```

### Expected Behavior

**Batch Processing:**
- Node 10: Split In Batches (batch size = 10)
- Total batches: 10
- Each batch processes 10 clinics concurrently

**Timing Breakdown (per batch):**
1. Scrape Google Maps: 30s
2. Scrape Reviews (10 clinics): 45s
3. Email enrichment (10 clinics): 30s
4. Email verification (20 emails): 15s
5. Pain analysis (10 clinics): 25s (Claude API)
6. Database storage: 5s
7. Email generation (10 clinics): 20s

**Per Batch Total:** ~170 seconds (2.8 minutes)
**10 Batches Total:** ~28 minutes

**System Resource Monitoring:**
- CPU: Should stay under 80%
- RAM: Should stay under 4GB
- Network: Bursty (high during scraping, low during processing)
- API Rate Limits: Should NOT hit limits with proper backoff

**Error Tolerance:**
- Acceptable: 5-10 clinics fail due to transient errors
- Retry logic should recover most failures
- Circuit breaker should NOT trigger (< 5 consecutive failures)

### Success Criteria

1. ✅ Workflow completes all 100 clinics
2. ✅ Completion time: 25-35 minutes (acceptable range)
3. ✅ At least 90/100 clinics processed successfully
4. ✅ No system crashes or out-of-memory errors
5. ✅ No API rate limit circuit breakers triggered
6. ✅ Database performance stable (query time < 100ms)
7. ✅ All 10 batches complete (batch processing working correctly)
8. ✅ Summary email received with accurate counts
9. ✅ Google Sheets backup contains all records
10. ✅ Tier distribution reasonable:
    - Tier A: 30-50 clinics (30-50%)
    - Tier B: 25-40 clinics (25-40%)
    - Tier C: 10-30 clinics (10-30%)

### Performance Benchmarks

| Metric | Target | Acceptable | Fail |
|--------|--------|------------|------|
| Total Time | < 30 min | 30-40 min | > 40 min |
| Success Rate | > 95% | 90-95% | < 90% |
| Avg Time per Clinic | < 18s | 18-24s | > 24s |
| API Errors | < 5 | 5-10 | > 10 |
| Database Errors | 0 | 1-2 | > 2 |
| Memory Usage | < 3GB | 3-4GB | > 4GB |
| CPU Usage (avg) | < 60% | 60-80% | > 80% |

### Verification Queries

```sql
-- Total count
SELECT COUNT(*) as total FROM pt_clinic_leads WHERE city = 'Phoenix';
-- Expected: 90-100

-- Success rate
SELECT
  COUNT(*) as total,
  COUNT(CASE WHEN primary_email IS NOT NULL THEN 1 END) as with_email,
  COUNT(CASE WHEN pain_categories != '[]'::jsonb THEN 1 END) as with_pain,
  COUNT(CASE WHEN email_subject IS NOT NULL THEN 1 END) as with_generated_email
FROM pt_clinic_leads
WHERE city = 'Phoenix';
-- Expected: High success rates

-- Tier distribution
SELECT tier, COUNT(*) as count, ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER () * 100, 1) as percentage
FROM pt_clinic_leads
WHERE city = 'Phoenix'
GROUP BY tier
ORDER BY tier;
-- Expected: Balanced distribution

-- Lead score statistics
SELECT
  MIN(lead_score) as min_score,
  MAX(lead_score) as max_score,
  ROUND(AVG(lead_score), 1) as avg_score,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lead_score) as median_score
FROM pt_clinic_leads
WHERE city = 'Phoenix';
-- Expected: Reasonable distribution (avg 60-80)

-- Check for errors
SELECT error_category, COUNT(*) as count
FROM workflow_errors
WHERE timestamp > NOW() - INTERVAL '1 hour'
GROUP BY error_category
ORDER BY count DESC;
-- Expected: < 10 total errors

-- Timing analysis (if created_at timestamps are sequential)
SELECT
  MIN(created_at) as first_record,
  MAX(created_at) as last_record,
  MAX(created_at) - MIN(created_at) as duration
FROM pt_clinic_leads
WHERE city = 'Phoenix';
-- Expected: Duration ~25-35 minutes
```

### Stress Test Observations

**Record:**
1. Exact start time: ___:___
2. Exact end time: ___:___
3. Total duration: ___ minutes
4. Records created: ___ / 100
5. Errors encountered: ___
6. Max CPU usage: ___%
7. Max RAM usage: ___GB
8. API rate limit hits: ___
9. Circuit breaker triggers: ___
10. Overall assessment: PASS / FAIL

### Edge Cases Covered

- ✅ High volume processing (100 items)
- ✅ Batch processing at scale (10 batches)
- ✅ Concurrent API requests (10 per batch)
- ✅ API quota management
- ✅ Database performance under load
- ✅ Memory management (no leaks)
- ✅ Error recovery at scale
- ✅ Summary statistics with large dataset

---

## Performance Benchmarks

### Expected Performance Metrics

| Stage | Average Time | Bottleneck | Optimization |
|-------|--------------|------------|--------------|
| Google Maps Scraping | 3-5s per clinic | Playwright JS rendering | Use headless mode, disable images |
| Google Reviews Scraping | 4-8s per clinic | Infinite scroll loading | Limit to 50 reviews, newest first |
| Website Email Scraping | 2-4s per clinic | Page load time | Check only contact page first |
| Email Verification | 1-2s per email | ZeroBounce API | Verify top 5 only |
| Pain Analysis (Claude) | 2-4s per clinic | Claude API latency | Use Sonnet (not Opus) |
| Database Insert | 0.1-0.5s per clinic | Network latency | Batch inserts possible |
| Email Generation (Claude) | 2-4s per clinic | Claude API latency | Can parallelize |
| **Total per Clinic** | **15-25 seconds** | - | - |

### Scaling Recommendations

**For 100 clinics:**
- Use batch size 10 (optimal for n8n)
- Expected time: 25-40 minutes
- API costs: ~$8-12 (Claude: $6, ZeroBounce: $3, others: free)

**For 500 clinics:**
- Use batch size 10
- Expected time: 2-3 hours
- Run overnight or off-peak
- Monitor API quotas carefully

**For 1,000+ clinics:**
- Consider breaking into multiple workflow runs (200 per run)
- Use queue system (BullMQ + n8n)
- Implement distributed Playwright containers
- Use Claude batch API (50% cost savings, 24hr latency)

---

## Regression Testing Checklist

Run this checklist after ANY changes to workflow:

### Workflow Structure
- [ ] All 55 nodes present and connected
- [ ] No orphaned nodes (disconnected)
- [ ] Error handling nodes properly connected
- [ ] Circuit breaker logic intact

### Configuration Validation
- [ ] All environment variables set
- [ ] No hardcoded credentials in nodes
- [ ] All API timeouts set correctly (30s scraping, 10s DB)
- [ ] All retry logic configured (2 retries, exponential backoff)

### Happy Path Test (5 clinics)
- [ ] Input validation works
- [ ] Google Maps scraping successful
- [ ] Review scraping successful
- [ ] Email enrichment successful
- [ ] Email verification successful
- [ ] Pain analysis successful
- [ ] Lead scoring calculates correctly
- [ ] Database storage successful
- [ ] Backup to Google Sheets successful
- [ ] Email generation successful
- [ ] Summary notification received

### Error Handling Tests
- [ ] Invalid input rejected (Node 4)
- [ ] Duplicate detection works (Node 8b)
- [ ] Scraping timeout handled (Node 6, 11, 15)
- [ ] API rate limit handled (Node 29, 37)
- [ ] Database error handled (Node 35)
- [ ] Circuit breaker triggers after 5 failures (Node 52-53)

### Data Quality Checks
- [ ] Phone numbers cleaned correctly (10 digits)
- [ ] Domains extracted correctly (no www.)
- [ ] Emails scored correctly (personal > generic)
- [ ] Pain categories structured correctly (JSON)
- [ ] Lead scores in valid range (0-100)
- [ ] Tiers assigned correctly (A: 70+, B: 50-69, C: 0-49)

### Performance Tests
- [ ] Single clinic: < 20 seconds
- [ ] 10 clinics: < 5 minutes
- [ ] 50 clinics: < 20 minutes
- [ ] No memory leaks (RAM stable)
- [ ] No CPU spikes (< 80% avg)

### Output Validation
- [ ] Supabase records complete (all fields)
- [ ] Google Sheets backup matches Supabase
- [ ] Summary email accurate counts
- [ ] Webhook response has correct structure
- [ ] No duplicate records (place_id unique)

---

## TEST EXECUTION SUMMARY TEMPLATE

Use this template to record test results:

```
TEST EXECUTION REPORT
Date: ___________
Tester: ___________
n8n Version: ___________
Workflow Version: ___________

TEST RESULTS:
=============

Test Case 1: Happy Path (Austin, TX)
Status: ☐ PASS ☐ FAIL
Duration: ___ minutes
Leads Processed: ___ / 10
Notes: ________________

Test Case 2: Small City (Abilene, TX)
Status: ☐ PASS ☐ FAIL
Duration: ___ minutes
Leads Processed: ___ / 8
Notes: ________________

Test Case 3: Scraping Blocked
Status: ☐ PASS ☐ FAIL
Error Handled: ☐ YES ☐ NO
Notes: ________________

Test Case 4: Supabase Down
Status: ☐ PASS ☐ FAIL
Data Backed Up: ☐ YES ☐ NO
Notes: ________________

Test Case 5: Claude API Rate Limit
Status: ☐ PASS ☐ FAIL
Graceful Degradation: ☐ YES ☐ NO
Notes: ________________

Test Case 6: Zero Reviews
Status: ☐ PASS ☐ FAIL
Leads Processed: ___ / 10
Notes: ________________

Test Case 7: Email Verification Failures
Status: ☐ PASS ☐ FAIL
Leads Stored: ___ / 5
Notes: ________________

Test Case 8: Stress Test (100 clinics)
Status: ☐ PASS ☐ FAIL
Duration: ___ minutes
Leads Processed: ___ / 100
Success Rate: ___%
Notes: ________________

OVERALL ASSESSMENT:
===================
Total Tests: 8
Passed: ___
Failed: ___
Workflow Status: ☐ PRODUCTION READY ☐ NEEDS FIXES

CRITICAL ISSUES:
________________

RECOMMENDATIONS:
________________

APPROVED BY: ______________ DATE: __________
```

---

## CONCLUSION

This test specification provides comprehensive validation coverage for the PT Clinic Intelligence System:

- **8 Test Cases** covering happy path, edge cases, error scenarios, and stress testing
- **Detailed test procedures** with exact inputs, expected outputs, and verification queries
- **Performance benchmarks** for measuring system health
- **Regression testing checklist** for ongoing maintenance
- **Execution tracking templates** for documenting test results

### Next Steps After Testing

1. **Fix Critical Issues:** Address any FAIL results before production
2. **Optimize Performance:** If stress test exceeds 35 minutes, optimize bottlenecks
3. **Document Known Limitations:** Update architecture doc with test findings
4. **Production Deployment:** Deploy to production environment
5. **Monitoring Setup:** Configure alerts for circuit breakers, API quotas, error rates
6. **Ongoing Testing:** Run regression tests monthly or after updates

---

**Document Complete** ✅
**Total Test Cases:** 8
**Total Line Count:** 1,500+ lines
**Status:** Ready for Test Execution
