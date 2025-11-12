# PT Google Maps Contact Scraper - Technical Architecture

## 1. System Overview

### Purpose
Systematically scrape PT clinic contact information (phone, website, address) from Google Maps across target cities, focusing purely on business data while ignoring patient reviews.

### Scope
- **Input**: Manual trigger with city/state parameters
- **Processing**: Kapture browser automation → Extract business data → Store contacts
- **Output**: Postgres database with 500 clinics across 5 cities

### Constraints
- Google Maps rate limits: 3-second delays between clicks
- Kapture MCP required for browser control
- Manual trigger only (too risky for auto-schedule)
- Daily limit: 100 clinics max per run

### Success Criteria
- 500 total clinics across 5 cities
- 80%+ have phone OR website
- <5% non-PT businesses
- <2% duplicate rate

---

## 2. Data Flow

```
┌─────────────────┐
│  Manual Trigger │ (City: Phoenix, Limit: 100)
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  Kapture: Open Browser & Search Google Maps            │
│  → Wait for results → Scroll to load clinics           │
└────────┬────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  Kapture: Extract Clinic Cards (up to limit)           │
│  → Get: name, rating, review count, address snippet    │
└────────┬────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  Loop: For Each Clinic Card                            │
│    ├─ Kapture: Click card (opens detail panel)         │
│    ├─ Kapture: Extract phone, website, full address    │
│    ├─ Wait 3s (rate limit)                             │
│    └─ Store clinic data                                │
└────────┬────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  Filter Non-PT  │ (Check business type)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Dedupe Check   │ (Postgres: phone/address match)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  INSERT/Skip    │ (Store new clinics)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Slack Report   │ (Summary notification)
└─────────────────┘
```

---

## 3. Node Specifications

### Node 1: Manual Trigger with City Input
- **Type**: `n8n-nodes-base.manualTrigger`
- **Purpose**: Start workflow manually with city/state parameters
- **Config**:
  - Trigger type: Manual
  - Input fields:
    - city (text): "Phoenix"
    - state (text): "AZ"
    - limit (number): 100
    - search_query (text): "physical therapy clinic"
- **Output**: Workflow starts with input parameters
- **Error Handling**: N/A (manual execution)

---

### Node 2: Initialize Kapture Browser
- **Type**: `n8n-nodes-base.code` (calls Kapture MCP)
- **Purpose**: Open browser tab and navigate to Google Maps
- **Config**:
  ```javascript
  // Call Kapture MCP to open new tab
  const kaptureUrl = $env.KAPTURE_SERVER_URL || 'http://localhost:3000';

  // Use n8n HTTP Request to call Kapture new_tab API
  // Returns: { tabId: "abc-123" }
  ```
- **Output**: Browser tab ID
- **Error Handling**:
  - If Kapture not running: Fail with setup instructions
  - If browser doesn't open: Retry 3 times

---

### Node 3: Search Google Maps (Kapture Navigate)
- **Type**: `n8n-nodes-base.httpRequest` (Kapture MCP API)
- **Purpose**: Navigate to Google Maps search results
- **Config**:
  - Method: POST
  - URL: `http://localhost:3000/api/navigate`
  - Body:
    ```json
    {
      "tabId": "{{ $json.tabId }}",
      "url": "https://www.google.com/maps/search/{{ $json.search_query }}+{{ $json.city }}+{{ $json.state }}",
      "timeout": 30000
    }
    ```
- **Output**: Navigation complete
- **Error Handling**:
  - If timeout: Increase to 60s, retry once
  - If navigation fails: Alert and stop workflow

---

### Node 4: Wait for Results to Load
- **Type**: `n8n-nodes-base.wait`
- **Purpose**: Give Google Maps time to render results
- **Config**:
  - Amount: 5 seconds
  - Unit: seconds
- **Output**: Delay complete
- **Error Handling**: None needed (fixed delay)

---

### Node 5: Scrape Clinic List (Kapture Elements)
- **Type**: `n8n-nodes-base.httpRequest` (Kapture MCP API)
- **Purpose**: Extract clinic cards from search results
- **Config**:
  - Method: POST
  - URL: `http://localhost:3000/api/elements`
  - Body:
    ```json
    {
      "tabId": "{{ $json.tabId }}",
      "selector": "div[role='article']",
      "visible": "true"
    }
    ```
- **Output**: Array of clinic elements with metadata
- **Error Handling**:
  - If 0 results: Try fallback selector `a[aria-label*="Physical"]`
  - If still 0: Log error, send alert

---

### Node 6: Limit to Max Clinics
- **Type**: `n8n-nodes-base.code`
- **Purpose**: Limit clinic list to user-specified max
- **Config**:
  ```javascript
  const limit = $node["Manual Trigger"].json.limit;
  const clinics = $input.all().slice(0, limit);
  return clinics;
  ```
- **Output**: Trimmed clinic list
- **Error Handling**: None needed (array slice safe)

---

### Node 7: Loop Each Clinic (Split In Batches)
- **Type**: `n8n-nodes-base.splitInBatches`
- **Purpose**: Process clinics one at a time
- **Config**:
  - Batch size: 1
  - Options: reset=false
- **Output**: One clinic per iteration
- **Error Handling**: Continue on item failure

---

### Node 8: Click Clinic Card (Kapture Click)
- **Type**: `n8n-nodes-base.httpRequest` (Kapture MCP API)
- **Purpose**: Click clinic to open detail panel
- **Config**:
  - Method: POST
  - URL: `http://localhost:3000/api/click`
  - Body:
    ```json
    {
      "tabId": "{{ $json.tabId }}",
      "selector": "{{ $json.selector }}"
    }
    ```
- **Output**: Click executed, detail panel opens
- **Error Handling**:
  - If click fails: Try XPath selector
  - If still fails: Skip clinic, log error

---

### Node 9: Wait After Click
- **Type**: `n8n-nodes-base.wait`
- **Purpose**: Let detail panel load
- **Config**:
  - Amount: 3 seconds (rate limit)
  - Unit: seconds
- **Output**: Delay complete
- **Error Handling**: None needed

---

### Node 10: Extract Clinic Details (Kapture DOM)
- **Type**: `n8n-nodes-base.httpRequest` (Kapture MCP API)
- **Purpose**: Get phone, website, full address from detail panel
- **Config**:
  - Method: POST
  - URL: `http://localhost:3000/api/dom`
  - Body:
    ```json
    {
      "tabId": "{{ $json.tabId }}"
    }
    ```
- **Output**: HTML of detail panel
- **Error Handling**:
  - If DOM empty: Retry once
  - If critical data missing: Continue with partial data

---

### Node 11: Parse Clinic Data (Code Node)
- **Type**: `n8n-nodes-base.code`
- **Purpose**: Extract structured data from HTML
- **Config**:
  ```javascript
  const html = $json.dom;
  const city = $node["Manual Trigger"].json.city;
  const state = $node["Manual Trigger"].json.state;

  // Parse using regex/selectors
  const phone = html.match(/button[^>]*data-item-id[^>]*phone[^>]*>([^<]+)</)?.[1] || null;
  const website = html.match(/a[^>]*data-item-id[^>]*website[^>]*href="([^"]+)"/)?.[1] || null;
  const address = html.match(/button[^>]*data-item-id[^>]*address[^>]*>([^<]+)</)?.[1] || null;
  const businessType = html.match(/button[^>]*aria-label="[^"]*([^"]*Physical[^"]*)"[^>]*>/)?.[1] || 'Physical Therapy';

  return {
    json: {
      clinic_name: $json.clinic_name,
      phone: phone,
      website: website,
      address: address,
      city: city,
      state: state,
      business_type: businessType,
      rating: $json.rating,
      review_count: $json.review_count
    }
  };
  ```
- **Output**: Structured clinic data
- **Error Handling**: Set missing fields to null

---

### Node 12: Filter PT Businesses Only (Code Node)
- **Type**: `n8n-nodes-base.code`
- **Purpose**: Remove non-PT businesses
- **Config**:
  ```javascript
  const ptKeywords = ['physical therapy', 'physiotherapy', 'rehabilitation', 'sports medicine', 'pt clinic'];
  const excludeKeywords = ['chiropractic', 'massage', 'acupuncture'];

  const name = ($json.clinic_name || '').toLowerCase();
  const type = ($json.business_type || '').toLowerCase();

  // Check if PT related
  const isPT = ptKeywords.some(kw => name.includes(kw) || type.includes(kw));
  const isExcluded = excludeKeywords.some(kw => name.includes(kw) || type.includes(kw));

  if (isPT && !isExcluded) {
    return { json: $json };
  } else {
    return null; // Filter out
  }
  ```
- **Output**: Only PT clinics
- **Error Handling**: If all filtered, log warning

---

### Node 13: Check Duplicate (Postgres)
- **Type**: `n8n-nodes-base.postgres`
- **Purpose**: Check if clinic already exists
- **Config**:
  - Operation: Execute Query
  - Query:
    ```sql
    SELECT id FROM clinics_contact_info
    WHERE phone = $1 OR (address = $2 AND city = $3 AND state = $4)
    LIMIT 1
    ```
  - Parameters: `[$json.phone, $json.address, $json.city, $json.state]`
- **Output**: Existing record (if found) or empty
- **Error Handling**:
  - If query fails: Continue to INSERT (will hit constraint)

---

### Node 14: Branch: New vs Duplicate
- **Type**: `n8n-nodes-base.if`
- **Purpose**: Route to INSERT or Skip
- **Config**:
  - Condition: `{{ $json.id }}` exists
  - If exists: Route to Skip (log duplicate)
  - If not exists: Route to INSERT
- **Output**: Routed items
- **Error Handling**: Default to INSERT if condition fails

---

### Node 15: INSERT Clinic (Postgres)
- **Type**: `n8n-nodes-base.postgres`
- **Purpose**: Store new clinic contact info
- **Config**:
  - Operation: Insert
  - Table: clinics_contact_info
  - Columns:
    - clinic_name, phone, website, address, city, state
    - business_type, rating, review_count
  - Return fields: id, created_at
- **Output**: Inserted row
- **Error Handling**:
  - Retry 3 times on failure
  - If still fails: Append to backup JSON

---

### Node 16: Tag Operation (Set Node)
- **Type**: `n8n-nodes-base.set`
- **Purpose**: Tag as INSERT or SKIP for reporting
- **Config**:
  - Add field: operation = "insert" or "skip"
  - Include other fields: true
- **Output**: Tagged clinic data
- **Error Handling**: None needed

---

### Node 17: Merge Results
- **Type**: `n8n-nodes-base.merge`
- **Purpose**: Combine INSERTs and SKIPs
- **Config**:
  - Mode: Append
  - Input 1: INSERT results
  - Input 2: SKIP results
- **Output**: All operation results
- **Error Handling**: N/A (pass-through)

---

### Node 18: Close Browser Tab (Kapture)
- **Type**: `n8n-nodes-base.httpRequest` (Kapture MCP API)
- **Purpose**: Clean up browser tab
- **Config**:
  - Method: POST
  - URL: `http://localhost:3000/api/close`
  - Body: `{ "tabId": "{{ $json.tabId }}" }`
- **Output**: Tab closed
- **Error Handling**: Best effort (log if fails, not critical)

---

### Node 19: Generate Summary Report
- **Type**: `n8n-nodes-base.code`
- **Purpose**: Create summary of scraping results
- **Config**:
  ```javascript
  const allResults = $input.all();
  const inserts = allResults.filter(r => r.json.operation === 'insert');
  const skips = allResults.filter(r => r.json.operation === 'skip');

  const missingPhone = inserts.filter(r => !r.json.phone).length;
  const missingWebsite = inserts.filter(r => !r.json.website).length;

  const report = `📍 **Google Maps Scraping Report**\\n\\n` +
    `**City**: ${$node["Manual Trigger"].json.city}, ${$node["Manual Trigger"].json.state}\\n` +
    `**New Clinics Added**: ${inserts.length}\\n` +
    `**Duplicates Skipped**: ${skips.length}\\n` +
    `**Missing Phone**: ${missingPhone}\\n` +
    `**Missing Website**: ${missingWebsite}\\n`;

  return [{ json: { report, stats: { inserts: inserts.length, skips: skips.length } } }];
  ```
- **Output**: Formatted report
- **Error Handling**: If formatting fails, send raw JSON

---

### Node 20: Send Slack Notification
- **Type**: `n8n-nodes-base.httpRequest`
- **Purpose**: Send summary to Slack
- **Config**:
  - Method: POST
  - URL: `{{ $env.SLACK_WEBHOOK_URL }}`
  - Body: `{ "text": "{{ $json.report }}", "channel": "#pt-intelligence" }`
- **Output**: Slack notification sent
- **Error Handling**:
  - If Slack fails: Send email (backup)
  - If both fail: Log error

---

## 4. Integration Points

### Kapture MCP Server
- **Endpoint**: `http://localhost:3000`
- **Authentication**: None (local server)
- **Rate Limits**: N/A (local control)
- **Strategy**: 3-second delays between clicks
- **Fallback**: If Kapture down, fail workflow with setup instructions

### Google Maps
- **Endpoint**: `https://www.google.com/maps`
- **Authentication**: None (public data)
- **Rate Limits**: ~60 clicks/hour (conservative)
- **Strategy**: 3s delays, human-like behavior
- **Fallback**: If CAPTCHA, pause and alert for manual solve

### Postgres Database
- **Connection**: Environment variable
- **Authentication**: Password in env
- **Tables**: `clinics_contact_info`
- **Strategy**: Dedupe before INSERT
- **Fallback**: Save to temp JSON if connection fails

---

## 5. Error Handling

| Scenario | Detection | Recovery | Fallback |
|----------|-----------|----------|----------|
| **Kapture Not Running** | Connection refused | Fail with setup instructions | N/A (critical dependency) |
| **Google CAPTCHA** | CAPTCHA form detected | Pause workflow, alert user | Wait for manual solve, resume |
| **0 Results Found** | Empty clinic list | Log warning, try fallback selector | Complete workflow normally |
| **Click Fails** | Kapture error | Try XPath selector, then skip clinic | Continue with next clinic |
| **Detail Panel Timeout** | No DOM after 5s | Retry once with 10s timeout | Skip clinic if still fails |
| **Phone/Website Missing** | Null values | Store record with nulls | Valid (partial data useful) |
| **Postgres Connection Lost** | Connection timeout | Save to backup JSON | Retry in 1 hour |
| **Duplicate Detected** | ID exists in query | Skip INSERT, increment skip counter | Log for metrics |

---

## 6. Performance & Safety

### Estimated Execution Time
- Google Maps search: 5s
- Load results: 5s
- Scrape 100 clinics × 6s each: 600s (10 minutes)
- **Total**: ~11 minutes per city

### Rate Limiting Strategy
- **Between clicks**: 3 seconds (hard limit)
- **Between cities**: 1 hour (separate runs)
- **Daily max**: 100 clinics per run
- **Why**: Avoid Google detecting automation

### Success Metrics
After scraping all 5 cities:
- **Quantity**: 500 clinics total
- **Quality**: 80%+ have phone OR website
- **Accuracy**: <5% non-PT businesses
- **Duplicates**: <2% duplicate rate

---

## 7. Security & Privacy

### Data Privacy
- ✅ Public data only (Google Maps business listings)
- ✅ No PII (business contact info)
- ✅ No patient data
- ✅ No scraping of patient reviews

### Credentials Management
- ✅ Postgres password in environment variable
- ✅ Slack webhook in environment variable
- ✅ No API keys needed (Kapture is local)

### Input Validation
- ✅ Sanitize city/state inputs
- ✅ Limit max clinics to 200 (safety cap)
- ✅ Validate URLs before storing

---

## 8. Database Schema

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
    UNIQUE(phone),
    UNIQUE(address, city, state)
);

CREATE INDEX idx_city_state ON clinics_contact_info(city, state);
CREATE INDEX idx_phone ON clinics_contact_info(phone);
```

---

**Architecture Version**: 1.0
**Created**: 2025-11-11
**Author**: Claude Code
**Status**: Ready for Implementation
