# PT Reddit Pain Scraper - Implementation Guide

This guide provides exact node configurations for building the workflow in n8n.

---

## Node-by-Node Implementation

### 1. Schedule Trigger

**Node Type**: Schedule Trigger
**Node Name**: `Daily Trigger`

```json
{
  "parameters": {
    "rule": {
      "interval": [
        {
          "field": "cronExpression",
          "expression": "0 2 * * *"
        }
      ]
    },
    "timezone": "America/New_York"
  },
  "type": "n8n-nodes-base.scheduleTrigger",
  "typeVersion": 1.2,
  "position": [250, 300]
}
```

---

### 2. Subreddit Configuration

**Node Type**: Set
**Node Name**: `Config: Subreddits`

```json
{
  "parameters": {
    "mode": "manual",
    "duplicateItem": false,
    "assignments": {
      "assignments": [
        {
          "name": "subreddits",
          "type": "array",
          "value": "=[\"physicaltherapy\", \"PrivatePractice\", \"smallbusiness\"]"
        },
        {
          "name": "limit",
          "type": "number",
          "value": 50
        },
        {
          "name": "timeFilter",
          "type": "string",
          "value": "day"
        },
        {
          "name": "painKeywords",
          "type": "object",
          "value": "={{ {\n  emr: [\"emr\", \"ehr\", \"documentation\", \"charting\", \"software\"],\n  billing: [\"billing\", \"insurance\", \"claims\", \"reimbursement\"],\n  scheduling: [\"scheduling\", \"appointment\", \"calendar\", \"booking\"],\n  marketing: [\"marketing\", \"patients\", \"acquisition\", \"pricing\", \"cash-based\"],\n  operations: [\"workflow\", \"efficiency\", \"productivity\", \"burnout\"],\n  staffing: [\"hiring\", \"staff\", \"employees\", \"training\"]\n} }}"
        }
      ]
    }
  },
  "type": "n8n-nodes-base.set",
  "typeVersion": 3.4,
  "position": [450, 300]
}
```

---

### 3. Split Subreddits

**Node Type**: Split In Batches
**Node Name**: `Loop: Each Subreddit`

```json
{
  "parameters": {
    "batchSize": 1,
    "options": {
      "reset": false
    }
  },
  "type": "n8n-nodes-base.splitInBatches",
  "typeVersion": 3,
  "position": [650, 300]
}
```

**Expression**: Split on `{{ $json.subreddits }}`

---

### 4. Current Subreddit

**Node Type**: Code
**Node Name**: `Get Current Subreddit`

```json
{
  "parameters": {
    "mode": "runOnceForEachItem",
    "jsCode": "const config = $node[\"Config: Subreddits\"].json;\nconst index = $itemIndex;\nconst subreddit = config.subreddits[index];\n\nreturn {\n  json: {\n    subreddit: subreddit,\n    limit: config.limit,\n    timeFilter: config.timeFilter\n  }\n};"
  },
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [850, 300]
}
```

---

### 5. Delay Before Request

**Node Type**: Wait
**Node Name**: `Wait 2s (Rate Limit)`

```json
{
  "parameters": {
    "resume": "after",
    "amount": 2,
    "unit": "seconds"
  },
  "type": "n8n-nodes-base.wait",
  "typeVersion": 1.1,
  "position": [1050, 300]
}
```

---

### 6. Fetch Reddit Posts

**Node Type**: HTTP Request
**Node Name**: `GET Reddit Posts`

```json
{
  "parameters": {
    "method": "GET",
    "url": "=https://www.reddit.com/r/{{ $json.subreddit }}/new.json?limit={{ $json.limit }}&t={{ $json.timeFilter }}",
    "authentication": "none",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "User-Agent",
          "value": "PT-Intelligence-Bot/1.0"
        }
      ]
    },
    "options": {
      "timeout": 30000,
      "retry": {
        "maxTries": 3,
        "waitBetweenTries": 5000
      },
      "response": {
        "response": {
          "fullResponse": false,
          "responseFormat": "json"
        }
      }
    }
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.2,
  "position": [1250, 300]
}
```

---

### 7. Parse Reddit Response

**Node Type**: Code
**Node Name**: `Parse Posts`

```json
{
  "parameters": {
    "mode": "runOnceForAllItems",
    "jsCode": "const subreddit = $input.first().json.subreddit;\nconst response = $input.first().json;\n\nif (!response.data || !response.data.children || response.data.children.length === 0) {\n  return [];\n}\n\nconst posts = response.data.children.map(child => {\n  const post = child.data;\n  return {\n    subreddit: subreddit,\n    title: post.title,\n    selftext: post.selftext || '',\n    author: post.author,\n    score: post.score,\n    num_comments: post.num_comments,\n    url: `https://www.reddit.com${post.permalink}`,\n    created_utc: post.created_utc,\n    created_date: new Date(post.created_utc * 1000).toISOString()\n  };\n});\n\nreturn posts.map(post => ({ json: post }));"
  },
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [1450, 300]
}
```

---

### 8. Filter Owner Posts

**Node Type**: Code
**Node Name**: `Filter: Owner Pain Posts`

```json
{
  "parameters": {
    "mode": "runOnceForAllItems",
    "jsCode": "const painKeywords = $node[\"Config: Subreddits\"].json.painKeywords;\nconst allKeywords = Object.values(painKeywords).flat();\n\nfunction calculateRelevance(post) {\n  const text = `${post.title} ${post.selftext}`.toLowerCase();\n  let score = 0;\n\n  // Check for pain keywords\n  for (const keyword of allKeywords) {\n    if (text.includes(keyword.toLowerCase())) {\n      score += 1;\n    }\n  }\n\n  // Check for owner indicators\n  const ownerKeywords = ['owner', 'director', 'clinic', 'practice', 'my pt', 'our clinic', 'my practice', 'private practice'];\n  for (const keyword of ownerKeywords) {\n    if (text.includes(keyword)) {\n      score += 2;\n    }\n  }\n\n  // Check for question indicators (owners asking for help)\n  const helpKeywords = ['?', 'help', 'advice', 'recommend', 'struggling', 'looking for', 'need'];\n  for (const keyword of helpKeywords) {\n    if (text.includes(keyword)) {\n      score += 1;\n    }\n  }\n\n  return score;\n}\n\nconst allPosts = $input.all();\nconst filteredPosts = allPosts\n  .map(item => {\n    const post = item.json;\n    post.relevance_score = calculateRelevance(post);\n    return { json: post };\n  })\n  .filter(item => item.json.relevance_score >= 5); // Threshold\n\nif (filteredPosts.length === 0) {\n  console.log('No posts matched filter criteria');\n}\n\nreturn filteredPosts;"
  },
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [1650, 300]
}
```

---

### 9. Categorize with Claude

**Node Type**: OpenAI Chat Model (or Anthropic if available)
**Node Name**: `AI: Categorize Pain`

**Note**: Use n8n's AI nodes or HTTP Request to Claude API

```json
{
  "parameters": {
    "model": "claude-sonnet-4-5-20250929",
    "options": {
      "temperature": 0.3,
      "maxTokens": 500
    },
    "messages": {
      "messageType": "text",
      "message": "=Analyze this PT clinic discussion post and:\n1. Categorize into ONE of: emr, billing, scheduling, marketing, operations, staffing\n2. Extract the specific pain point in 1 clear sentence\n3. Rate severity 1-10\n\nPost Title: {{ $json.title }}\nPost Text: {{ $json.selftext }}\n\nRespond ONLY with valid JSON:\n{\n  \"pain_category\": \"category\",\n  \"pain_text\": \"specific problem in one sentence\",\n  \"severity_score\": 8\n}"
    }
  },
  "type": "@n8n/n8n-nodes-langchain.lmChatAnthropic",
  "typeVersion": 1,
  "position": [1850, 300],
  "credentials": {
    "anthropicApi": {
      "id": "1",
      "name": "Anthropic account"
    }
  }
}
```

**Alternative: HTTP Request to Claude API**

```json
{
  "parameters": {
    "method": "POST",
    "url": "https://api.anthropic.com/v1/messages",
    "authentication": "predefinedCredentialType",
    "nodeCredentialType": "anthropicApi",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "anthropic-version",
          "value": "2023-06-01"
        }
      ]
    },
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "model",
          "value": "claude-sonnet-4-5-20250929"
        },
        {
          "name": "max_tokens",
          "value": 500
        },
        {
          "name": "temperature",
          "value": 0.3
        },
        {
          "name": "messages",
          "value": "=[{\n  \"role\": \"user\",\n  \"content\": `Analyze this PT clinic discussion post and:\n1. Categorize into ONE of: emr, billing, scheduling, marketing, operations, staffing\n2. Extract the specific pain point in 1 clear sentence\n3. Rate severity 1-10\n\nPost Title: ${$json.title}\nPost Text: ${$json.selftext}\n\nRespond ONLY with valid JSON:\n{\n  \"pain_category\": \"category\",\n  \"pain_text\": \"specific problem in one sentence\",\n  \"severity_score\": 8\n}`\n}]"
        }
      ]
    },
    "options": {
      "retry": {
        "maxTries": 2
      }
    }
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.2,
  "position": [1850, 300]
}
```

---

### 10. Parse Claude Response

**Node Type**: Code
**Node Name**: `Parse AI Response`

```json
{
  "parameters": {
    "mode": "runOnceForEachItem",
    "jsCode": "const post = $json;\nconst aiResponse = $json.content?.[0]?.text || $json.choices?.[0]?.message?.content || JSON.stringify($json);\n\ntry {\n  // Extract JSON from response (Claude sometimes wraps in markdown)\n  const jsonMatch = aiResponse.match(/\\{[\\s\\S]*\\}/);\n  if (jsonMatch) {\n    const parsed = JSON.parse(jsonMatch[0]);\n    return {\n      json: {\n        ...post,\n        pain_category: parsed.pain_category,\n        pain_text: parsed.pain_text,\n        severity_score: parsed.severity_score\n      }\n    };\n  } else {\n    throw new Error('No JSON found in response');\n  }\n} catch (error) {\n  // Fallback if parsing fails\n  return {\n    json: {\n      ...post,\n      pain_category: 'uncategorized',\n      pain_text: post.title,\n      severity_score: 5,\n      ai_error: error.message,\n      raw_ai_response: aiResponse\n    }\n  };\n}"
  },
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [2050, 300]
}
```

---

### 11. Check for Duplicates

**Node Type**: Postgres
**Node Name**: `DB: Check Duplicate`

```json
{
  "parameters": {
    "operation": "executeQuery",
    "query": "=SELECT id, mentions, pain_text\nFROM pain_points\nWHERE example_urls @> jsonb_build_array(jsonb_build_object('url', '{{ $json.url }}'))\nLIMIT 1",
    "options": {}
  },
  "type": "n8n-nodes-base.postgres",
  "typeVersion": 2.5,
  "position": [2250, 300],
  "credentials": {
    "postgres": {
      "id": "1",
      "name": "Postgres account"
    }
  }
}
```

---

### 12. Merge Post with Duplicate Check

**Node Type**: Code
**Node Name**: `Merge: Post + Duplicate Check`

```json
{
  "parameters": {
    "mode": "runOnceForEachItem",
    "jsCode": "// Get the categorized post from previous node\nconst post = $input.first().json;\n\n// Get duplicate check result\nconst duplicateCheck = $input.last().json;\n\nreturn {\n  json: {\n    ...post,\n    existing_id: duplicateCheck.id || null,\n    existing_mentions: duplicateCheck.mentions || 0,\n    is_duplicate: !!duplicateCheck.id\n  }\n};"
  },
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [2450, 300]
}
```

---

### 13. Branch: New vs Existing

**Node Type**: IF
**Node Name**: `IF: Is Duplicate?`

```json
{
  "parameters": {
    "conditions": {
      "options": {
        "caseSensitive": true,
        "leftValue": "",
        "typeValidation": "strict"
      },
      "conditions": [
        {
          "leftValue": "={{ $json.is_duplicate }}",
          "rightValue": true,
          "operator": {
            "type": "boolean",
            "operation": "equals"
          }
        }
      ],
      "combinator": "and"
    },
    "options": {}
  },
  "type": "n8n-nodes-base.if",
  "typeVersion": 2,
  "position": [2650, 300]
}
```

**Output**:
- True → UPDATE node
- False → INSERT node

---

### 14a. INSERT New Pain Point

**Node Type**: Postgres
**Node Name**: `DB: INSERT New`

```json
{
  "parameters": {
    "operation": "insert",
    "table": "pain_points",
    "columns": {
      "columns": [
        {
          "column": "source",
          "value": "reddit"
        },
        {
          "column": "pain_category",
          "value": "={{ $json.pain_category }}"
        },
        {
          "column": "pain_text",
          "value": "={{ $json.pain_text }}"
        },
        {
          "column": "severity_score",
          "value": "={{ $json.severity_score }}"
        },
        {
          "column": "mentions",
          "value": 1
        },
        {
          "column": "example_urls",
          "value": "=[{ url: $json.url, subreddit: $json.subreddit, title: $json.title }]"
        }
      ]
    },
    "options": {
      "returnFields": "id,created_at"
    }
  },
  "type": "n8n-nodes-base.postgres",
  "typeVersion": 2.5,
  "position": [2850, 250],
  "credentials": {
    "postgres": {
      "id": "1",
      "name": "Postgres account"
    }
  }
}
```

---

### 14b. UPDATE Existing Pain Point

**Node Type**: Postgres
**Node Name**: `DB: UPDATE Existing`

```json
{
  "parameters": {
    "operation": "update",
    "table": "pain_points",
    "updateKey": "id",
    "columns": {
      "columns": [
        {
          "column": "mentions",
          "value": "={{ $json.existing_mentions + 1 }}"
        },
        {
          "column": "example_urls",
          "value": "=example_urls || jsonb_build_array(jsonb_build_object('url', '{{ $json.url }}', 'subreddit', '{{ $json.subreddit }}', 'title', '{{ $json.title }}'))"
        }
      ]
    },
    "options": {
      "returnFields": "id,mentions"
    }
  },
  "type": "n8n-nodes-base.postgres",
  "typeVersion": 2.5,
  "position": [2850, 350],
  "credentials": {
    "postgres": {
      "id": "1",
      "name": "Postgres account"
    }
  }
}
```

---

### 15. Tag Operation Type

**Node Type**: Set (for INSERT)
**Node Name**: `Tag: INSERT`

```json
{
  "parameters": {
    "mode": "manual",
    "assignments": {
      "assignments": [
        {
          "name": "operation",
          "value": "insert",
          "type": "string"
        }
      ]
    },
    "options": {
      "includeOtherFields": true
    }
  },
  "type": "n8n-nodes-base.set",
  "typeVersion": 3.4,
  "position": [3050, 250]
}
```

**Duplicate for UPDATE**: Change value to "update", position [3050, 350]

---

### 16. Merge Results

**Node Type**: Merge
**Node Name**: `Merge: All DB Operations`

```json
{
  "parameters": {
    "mode": "append",
    "options": {}
  },
  "type": "n8n-nodes-base.merge",
  "typeVersion": 2.1,
  "position": [3250, 300]
}
```

---

### 17. Generate Summary Report

**Node Type**: Code
**Node Name**: `Generate Report`

```json
{
  "parameters": {
    "mode": "runOnceForAllItems",
    "jsCode": "const allResults = $input.all();\nconst inserts = allResults.filter(r => r.json.operation === 'insert');\nconst updates = allResults.filter(r => r.json.operation === 'update');\n\n// Group by category\nconst byCategory = {};\nfor (const result of inserts) {\n  const cat = result.json.pain_category;\n  if (!byCategory[cat]) {\n    byCategory[cat] = { count: 0, examples: [] };\n  }\n  byCategory[cat].count++;\n  if (byCategory[cat].examples.length < 3) {\n    byCategory[cat].examples.push(result.json.pain_text);\n  }\n}\n\n// Format markdown report\nconst today = new Date().toISOString().split('T')[0];\nlet report = `📊 **Reddit Pain Point Summary - ${today}**\\n\\n`;\nreport += `**New Pain Points**: ${inserts.length}\\n`;\nreport += `**Updated Pain Points**: ${updates.length}\\n\\n`;\n\nif (Object.keys(byCategory).length > 0) {\n  report += `**By Category**:\\n`;\n  for (const [category, data] of Object.entries(byCategory).sort((a, b) => b[1].count - a[1].count)) {\n    report += `\\n**${category.toUpperCase()}** (${data.count} mentions)\\n`;\n    data.examples.forEach(ex => report += `• ${ex}\\n`);\n  }\n} else {\n  report += `No new pain points discovered today.\\n`;\n}\n\nreturn [{\n  json: {\n    report,\n    stats: {\n      inserts: inserts.length,\n      updates: updates.length,\n      total: allResults.length,\n      categories: Object.keys(byCategory).length\n    },\n    date: today\n  }\n}];"
  },
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [3450, 300]
}
```

---

### 18. Send Slack Notification

**Node Type**: HTTP Request
**Node Name**: `Slack: Send Summary`

```json
{
  "parameters": {
    "method": "POST",
    "url": "={{ $env.SLACK_WEBHOOK_URL }}",
    "authentication": "none",
    "sendBody": true,
    "contentType": "application/json",
    "body": "={{ JSON.stringify({ text: $json.report, channel: '#pt-intelligence' }) }}",
    "options": {
      "retry": {
        "maxTries": 2,
        "waitBetweenTries": 3000
      }
    }
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.2,
  "position": [3650, 300]
}
```

---

### 19. Error Handler (Optional)

**Node Type**: Error Trigger
**Node Name**: `On Workflow Error`

```json
{
  "parameters": {},
  "type": "n8n-nodes-base.errorTrigger",
  "typeVersion": 1,
  "position": [250, 500]
}
```

Connect to a Slack notification node that sends error details.

---

## Connections

```
Daily Trigger → Config: Subreddits → Loop: Each Subreddit → Get Current Subreddit → Wait 2s → GET Reddit Posts → Parse Posts → Filter Owner Posts → AI: Categorize Pain → Parse AI Response → DB: Check Duplicate → Merge Post + Duplicate Check → IF: Is Duplicate?

IF: Is Duplicate? (False) → DB: INSERT New → Tag: INSERT → Merge: All DB Operations
IF: Is Duplicate? (True) → DB: UPDATE Existing → Tag: UPDATE → Merge: All DB Operations

Merge: All DB Operations → Generate Report → Slack: Send Summary
```

---

## Environment Variables Setup

In n8n, go to Settings → Environment Variables:

```
POSTGRES_CONNECTION_STRING=postgresql://user:pass@localhost:5432/pt_clinic_intel
CLAUDE_API_KEY=sk-ant-api03-...
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T.../B.../...
```

---

## Execution Settings

Workflow Settings:
- **Timeout**: 10 minutes
- **Execution Order**: v1 (sequential)
- **Save Data on Success**: Yes
- **Save Data on Error**: Yes
- **Timezone**: America/New_York

---

**Implementation Version**: 1.0
**Tested on n8n Version**: 1.19+
**Estimated Build Time**: 2-3 hours
