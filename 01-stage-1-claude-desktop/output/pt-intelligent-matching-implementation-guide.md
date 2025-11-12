# PT Intelligent Matching System - Implementation Guide (Streamlined)

## Workflow Overview
Schedule/Manual trigger → Fetch unmatched clinics → Loop → Match pain categories → Generate outreach (Claude) → Store matches → Slack report

**Total Nodes**: 12
**Execution Time**: ~5 minutes per 100 clinics
**Dependencies**: Postgres, Claude API, Slack

---

## Essential Node Configurations

### 1. Schedule Trigger
```json
{
  "type": "n8n-nodes-base.scheduleTrigger",
  "parameters": {
    "rule": {
      "interval": [{"field": "cronExpression", "expression": "0 9 * * 1"}]
    },
    "timezone": "America/New_York"
  }
}
```
**Schedule**: Every Monday at 9 AM EST

### 2. Get Unmatched Clinics (Postgres)
```sql
SELECT c.id, c.clinic_name, c.business_type, c.city, c.state
FROM clinics_contact_info c
LEFT JOIN matched_segments m ON c.id = m.clinic_id
WHERE m.id IS NULL AND c.business_type IS NOT NULL
LIMIT 100
```

### 3. Split Clinics (Batches)
```json
{
  "type": "n8n-nodes-base.splitInBatches",
  "parameters": {
    "batchSize": 10,
    "options": {}
  }
}
```

### 4. Get Relevant Pain Points (Postgres)
```sql
SELECT id, pain_category, pain_text, severity_score, source
FROM pain_points
WHERE state = $1 OR state IS NULL
ORDER BY severity_score DESC, mentions DESC
LIMIT 20
```
**Parameters**: $1 = clinic.state

### 5. Match Business Type to Pain Category (Code)
```javascript
const businessType = ($json.business_type || '').toLowerCase();
const painPoints = $input.all();

// Business type → Pain category mapping
const categoryMap = {
  'sports medicine': ['scheduling', 'operations'],
  'physical therapy': ['emr', 'billing', 'scheduling'],
  'orthopedic': ['operations', 'staffing'],
  'cash-based': ['marketing', 'billing'],
  'rehabilitation': ['emr', 'operations']
};

// Find matching categories
let matchedCategories = [];
for (const [type, categories] of Object.entries(categoryMap)) {
  if (businessType.includes(type)) {
    matchedCategories = categories;
    break;
  }
}

// Default to common pain points if no match
if (matchedCategories.length === 0) {
  matchedCategories = ['scheduling', 'marketing'];
}

// Filter pain points by matched categories
const relevantPains = painPoints.filter(p =>
  matchedCategories.includes(p.json.pain_category)
);

// Score and rank pain points
const scoredPains = relevantPains.map(p => {
  let score = 0;
  score += p.json.severity_score * 0.3;  // 30% severity
  score += (p.json.state === $json.state ? 40 : 0);  // 40% geography
  score += (matchedCategories.includes(p.json.pain_category) ? 30 : 0);  // 30% category match
  return { ...p.json, match_score: score };
});

// Return top 3 pain points
const topPains = scoredPains
  .sort((a, b) => b.match_score - a.match_score)
  .slice(0, 3);

return [{ json: {
  clinic_id: $json.id,
  clinic_name: $json.clinic_name,
  business_type: $json.business_type,
  city: $json.city,
  state: $json.state,
  top_pain_points: topPains,
  matched_categories: matchedCategories,
  match_confidence: topPains.length >= 3 ? 0.85 : 0.6
}}];
```

### 6. Generate Outreach Message (Claude API)
```json
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "method": "POST",
    "url": "https://api.anthropic.com/v1/messages",
    "authentication": "predefinedCredentialType",
    "nodeCredentialType": "anthropicApi",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [{"name": "anthropic-version", "value": "2023-06-01"}]
    },
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "= CONSTRUCT_JSON_BODY",
    "options": {}
  }
}
```

**JSON Body Construction** (use string concatenation in jsonBody):
```javascript
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 500,
  "messages": [{
    "role": "user",
    "content": "Write a 2-3 sentence personalized outreach message for a PT clinic. Clinic: " + $json.clinic_name + " (" + $json.business_type + ") in " + $json.city + ", " + $json.state + ". Top pain points they likely face: " + JSON.stringify($json.top_pain_points) + ". Make it conversational and mention specific pain points."
  }]
}
```

### 7. Parse Outreach Message (Code)
```javascript
const response = JSON.parse($json.body);
const outreachMessage = response.content[0].text.trim();

return [{ json: {
  clinic_id: $node['Match Business Type to Pain Category'].json.clinic_id,
  clinic_name: $node['Match Business Type to Pain Category'].json.clinic_name,
  pain_point_ids: $node['Match Business Type to Pain Category'].json.top_pain_points.map(p => p.id),
  outreach_message: outreachMessage,
  match_confidence: $node['Match Business Type to Pain Category'].json.match_confidence,
  matched_categories: $node['Match Business Type to Pain Category'].json.matched_categories
}}];
```

### 8. Store Match (Postgres)
```sql
INSERT INTO matched_segments (
  clinic_id,
  pain_point_ids,
  outreach_message,
  match_confidence,
  matched_categories,
  created_at
) VALUES (
  $1, $2, $3, $4, $5, NOW()
)
ON CONFLICT (clinic_id) DO UPDATE SET
  pain_point_ids = EXCLUDED.pain_point_ids,
  outreach_message = EXCLUDED.outreach_message,
  match_confidence = EXCLUDED.match_confidence,
  updated_at = NOW()
```

**Parameters**:
- $1: clinic_id
- $2: pain_point_ids (JSONB array)
- $3: outreach_message
- $4: match_confidence
- $5: matched_categories (JSONB array)

### 9. Generate Summary Report (Code)
```javascript
const allMatches = $input.all();
const highConfidence = allMatches.filter(m => m.json.match_confidence > 0.8);
const mediumConfidence = allMatches.filter(m => m.json.match_confidence >= 0.5 && m.json.match_confidence <= 0.8);

const report = '🎯 **Intelligent Matching Report**\n\n' +
  '**Total Clinics Matched**: ' + allMatches.length + '\n' +
  '**High Confidence**: ' + highConfidence.length + ' (>0.8)\n' +
  '**Medium Confidence**: ' + mediumConfidence.length + ' (0.5-0.8)\n' +
  '**Top Categories**: ' + [...new Set(allMatches.flatMap(m => m.json.matched_categories))].join(', ') + '\n';

return [{ json: { report, stats: {
  total: allMatches.length,
  high: highConfidence.length,
  medium: mediumConfidence.length
}}}];
```

### 10. Slack Notification
```json
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "method": "POST",
    "url": "={{ $env.SLACK_WEBHOOK_URL }}",
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "= { \"text\": $json.report, \"channel\": \"#pt-intelligence\" }",
    "options": {}
  }
}
```

---

## Critical Settings
- **Batch Size**: 10 clinics (prevent Claude API rate limits)
- **Match Confidence Threshold**: 0.5 minimum (skip low-confidence matches)
- **Pain Point Limit**: Top 3 per clinic (avoid message overload)
- **Retry Logic**: 3 attempts for Claude API failures

---

## Environment Variables
```bash
POSTGRES_CONNECTION_STRING=postgresql://...
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
ANTHROPIC_API_KEY=sk-ant-...  # Set in n8n credentials
```

---

## Database Schema Requirements
```sql
-- matched_segments table
CREATE TABLE IF NOT EXISTS matched_segments (
    id SERIAL PRIMARY KEY,
    clinic_id INTEGER REFERENCES clinics_contact_info(id),
    pain_point_ids JSONB,
    outreach_message TEXT,
    match_confidence DECIMAL(3,2),
    matched_categories JSONB,
    decision_maker_id INTEGER REFERENCES decision_makers(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(clinic_id)
);
```
