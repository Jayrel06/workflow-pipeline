# PT Google Maps Contact Scraper - Implementation Guide (Streamlined)

## Workflow Overview
Manual trigger → Kapture browser → Search Google Maps → Click clinics → Extract contacts → Store in Postgres

**Total Nodes**: 15
**Execution Time**: ~10 minutes per city
**Dependencies**: Kapture MCP, Postgres

---

## Essential Node Configurations

### 1. Manual Trigger
```json
{
  "type": "n8n-nodes-base.manualTrigger",
  "parameters": {
    "inputs": [
      {"name": "city", "type": "string", "default": "Phoenix"},
      {"name": "state", "type": "string", "default": "AZ"},
      {"name": "limit", "type": "number", "default": 100}
    ]
  }
}
```

### 2-5. Kapture: Search & Extract Clinics
Use Kapture MCP tools: `new_tab` → `navigate` → `elements`
- Search URL: `https://www.google.com/maps/search/physical+therapy+clinic+{city}+{state}`
- Selector: `div[role="article"]`
- Extract: clinic name, rating, address snippet

### 6-8. Loop Clinics: Click & Extract Details
For each clinic:
- Kapture `click` on card
- Wait 3 seconds
- Kapture `dom` to get HTML
- Parse: phone, website, full address

### 9. Filter PT Only (Code)
```javascript
const ptKeywords = ['physical therapy', 'pt', 'physiotherapy', 'rehabilitation'];
const excludeKeywords = ['chiropractic', 'massage', 'acupuncture'];
// Filter logic
```

### 10-11. Dedupe & Store (Postgres)
```sql
-- Check duplicate
SELECT id FROM clinics_contact_info WHERE phone = $1 OR address = $2 LIMIT 1

-- Insert new
INSERT INTO clinics_contact_info (clinic_name, phone, website, address, city, state, business_type, rating, review_count)
```

### 12. Report & Notify (Slack)
Summary: X new clinics, Y duplicates, Z missing data

---

## Critical Settings
- **Rate Limit**: 3s wait after each click
- **Max Clinics**: 100 per run (safety)
- **Error Handling**: Skip failed clinics, continue workflow
- **Deduplication**: By phone OR (address + city + state)

---

## Environment Variables
```bash
POSTGRES_CONNECTION_STRING=postgresql://...
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
KAPTURE_SERVER_URL=http://localhost:3000
```
