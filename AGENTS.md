# AGENTS.md - n8n Workflow Pipeline Review Guidelines

## Project Overview
**Repository:** workflow-pipeline
**Owner:** jayrel06
**Purpose:** Multi-AI n8n workflow validation system
**Tech Stack:** n8n, Apify, VAPI, Retell, Supabase, OpenAI, Twilio, Google Sheets, Playwright

---

## Review Philosophy

Codex acts as a **paranoid senior engineer** who:
- Assumes AI-generated code has bugs (because it does)
- Validates EVERY external API integration
- Checks error handling at EVERY failure point
- Ensures HIPAA compliance for patient data
- Prevents cost explosions from API over-usage
- Questions everything until proven correct

**Core Principle:** *"Trust, but verify everything"*

---

## Critical Issues (P0) - **BLOCK MERGE**

These issues MUST be fixed before merging. They represent security vulnerabilities, data loss risks, or critical functional failures.

### ❌ P0-1: Missing Error Handling

**What to check:**
- Every `n8n-nodes-base.httpRequest` node has `continueOnFail: true` OR error branch
- Every external API call has timeout configured (default: 30000ms)
- Every database operation has try/catch equivalent
- Every webhook has fallback path
- Every file operation has error handling

**Why this matters:**
- Workflows crash completely on any API failure
- No way to recover from transient errors
- User data can be lost mid-process
- No logging of what went wrong

**Examples:**

```json
// ❌ BAD - Will crash workflow on API failure
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://api.openai.com/v1/chat/completions",
    "method": "POST"
  }
}

// ✅ GOOD - Continues workflow, routes to error handler
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://api.openai.com/v1/chat/completions",
    "method": "POST"
  },
  "continueOnFail": true,
  "onError": "continueRegularOutput"
}

// ✅ BETTER - With retry logic
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://api.openai.com/v1/chat/completions",
    "method": "POST",
    "options": {
      "timeout": 60000,
      "retry": {
        "enabled": true,
        "maxRetries": 3,
        "waitBetween": 5000
      }
    }
  },
  "continueOnFail": true,
  "onError": "continueRegularOutput"
}
```

**Detection Pattern:**
```regex
"n8n-nodes-base\.httpRequest".*(?!continueOnFail)
```

**How to fix:**
1. Add `"continueOnFail": true` to node parameters
2. Add error branch connection to error handling node
3. Include timeout in options
4. Enable retry logic for external APIs

---

### ❌ P0-2: Hardcoded Credentials

**What to check:**
- NO `"apiKey": "sk-..."` patterns
- NO `"password": "..."` in plain text
- NO `"token": "..."` hardcoded
- NO `"Authorization": "Bearer abc123"`
- ALL credentials use: `"={{$env.VARIABLE_NAME}}"`

**Why this matters:**
- Credentials exposed in Git history (can't be removed)
- Anyone with repo access has API keys
- Credentials can't be rotated without code changes
- Violates OWASP Top 10 security standards

**Detection Patterns:**
```regex
("api[_-]?key"|"password"|"secret"|"token"|"bearer")["']\s*:\s*["'][a-zA-Z0-9]{10,}["']
```

**Examples:**

```json
// ❌ CRITICAL SECURITY ISSUE
{
  "sendHeaders": true,
  "headerParameters": {
    "parameters": [
      {
        "name": "Authorization",
        "value": "Bearer sk-proj-abc123xyz789"
      }
    ]
  }
}

// ✅ CORRECT - Uses environment variable
{
  "sendHeaders": true,
  "headerParameters": {
    "parameters": [
      {
        "name": "Authorization",
        "value": "Bearer ={{$env.OPENAI_API_KEY}}"
      }
    ]
  }
}

// ❌ DANGEROUS - Hardcoded database password
{
  "url": "postgresql://user:mypassword123@localhost:5432/db"
}

// ✅ CORRECT - Uses environment variables
{
  "url": "={{$env.DATABASE_URL}}"
}
```

**How to fix:**
1. Move ALL credentials to environment variables
2. Use n8n credentials system when possible
3. Document required env vars in README
4. Add .env.example file with placeholder values
5. Rotate any exposed credentials immediately

---

### ❌ P0-3: Unsafe Webhook Configuration

**What to check:**
- All webhook nodes have `authenticate: true`
- Authentication method configured (headerAuth, basicAuth, JWT)
- Webhook paths are unique and non-guessable
- No sensitive data logged from webhook input
- Input validation before processing webhook data

**Why this matters:**
- Unauthenticated webhooks = anyone can trigger workflow
- Attackers can inject malicious data
- Cost explosion from spam webhook calls
- Data corruption from invalid inputs

**Examples:**

```json
// ❌ CRITICAL SECURITY ISSUE - No authentication
{
  "type": "n8n-nodes-base.webhook",
  "parameters": {
    "path": "patient-intake",
    "httpMethod": "POST",
    "responseMode": "onReceived"
  }
}

// ✅ CORRECT - Header authentication required
{
  "type": "n8n-nodes-base.webhook",
  "parameters": {
    "path": "patient-intake-a7b3c9d2",
    "httpMethod": "POST",
    "responseMode": "onReceived",
    "authentication": "headerAuth"
  },
  "credentials": {
    "httpHeaderAuth": {
      "id": "webhook_secret_001",
      "name": "Patient Intake Webhook Secret"
    }
  }
}

// ✅ ALSO GOOD - Basic auth
{
  "type": "n8n-nodes-base.webhook",
  "parameters": {
    "path": "secure-webhook-endpoint",
    "httpMethod": "POST",
    "authentication": "basicAuth"
  },
  "credentials": {
    "httpBasicAuth": {
      "id": "basic_auth_001",
      "name": "Webhook Basic Auth"
    }
  }
}
```

**Additional Webhook Security:**
- Use IP whitelist option if traffic comes from known IPs
- Enable "Ignore Bots" option to block crawlers
- Set maximum payload size to prevent DoS
- Use non-obvious webhook paths (include random string)

**How to fix:**
1. Enable authentication on webhook node
2. Create credential in n8n for webhook auth
3. Document webhook URL and auth method
4. Add validation node immediately after webhook
5. Use unique, non-guessable paths

---

### ❌ P0-4: Missing Rate Limiting

**What to check:**
- OpenAI API: Max 50 requests/min (Tier 1)
- Twilio SMS: Max 1000/day on free tier
- Google Maps: Max 100 queries/day (free)
- Apify: Monitor credit usage ($/compute unit)
- Custom APIs: Check rate limits in docs

**Why this matters:**
- Cost explosions ($200+ unexpected charges)
- Account bans from API providers
- Degraded performance for other users
- Service disruptions

**Implementation:**

```json
// Add delay between API calls
{
  "type": "n8n-nodes-base.wait",
  "parameters": {
    "amount": 1200,  // 1.2 seconds = ~50 req/min
    "unit": "milliseconds"
  }
}

// For batch operations, split with delays
{
  "type": "n8n-nodes-base.splitInBatches",
  "parameters": {
    "batchSize": 10,
    "options": {
      "reset": false
    }
  }
}
// Then add Wait node after processing each batch
```

**Detection:**
- Look for loops calling external APIs without delays
- Check for bulk operations without batching
- Flag any OpenAI calls without rate consideration

**How to fix:**
1. Add Wait nodes between API calls
2. Use splitInBatches for bulk operations
3. Implement queue system for high-volume workflows
4. Monitor API usage with external tools
5. Set up alerts for usage thresholds

---

### ❌ P0-5: HIPAA Violations (PT Clinic Data)

**What to check:**
- NO patient names in console.log statements
- NO PHI (Protected Health Information) in error messages
- All PHI encrypted in database (Supabase RLS enabled)
- Audit logging for all PHI access
- Minimum necessary principle (only access needed PHI)

**PHI Includes:**
- Patient names
- Phone numbers
- Email addresses
- Appointment details
- Medical conditions
- Any health-related data
- Payment information

**Examples:**

```json
// ❌ HIPAA VIOLATION
{
  "type": "n8n-nodes-base.code",
  "parameters": {
    "jsCode": "console.log('Processing patient:', $json.patient_name);\nreturn $json;"
  }
}

// ✅ CORRECT - No PHI in logs
{
  "type": "n8n-nodes-base.code",
  "parameters": {
    "jsCode": "console.log('Processing patient ID:', $json.patient_id);\nreturn $json;"
  }
}

// ❌ DANGEROUS - PHI in error message
{
  "onError": "continueRegularOutput",
  "parameters": {
    "errorMessage": "Failed to send SMS to {{$json.patient_phone}}"
  }
}

// ✅ CORRECT - Generic error message
{
  "onError": "continueRegularOutput",
  "parameters": {
    "errorMessage": "Failed to send notification to patient {{$json.patient_id}}"
  }
}
```

**Supabase RLS Requirements:**

```sql
-- Must have Row Level Security enabled
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;

-- Must have policies for access control
CREATE POLICY "Users can only view own patients"
ON patients FOR SELECT
USING (auth.uid() = clinic_owner_id);
```

**How to fix:**
1. Audit all console.log statements
2. Remove PHI from error messages
3. Use patient_id instead of names in logs
4. Enable Supabase RLS on all PHI tables
5. Implement audit logging for PHI access
6. Encrypt PHI at rest (Supabase handles this)
7. Use HTTPS for all PHI transmission

---

## Important Issues (P1) - **SHOULD FIX**

These issues should be fixed but won't block merge. They represent best practices and robustness improvements.

### ⚠️ P1-1: Missing Data Validation

**What to check:**
- Input validation BEFORE external API calls
- Null checks on API responses before using data
- Email format validation (regex)
- Phone number format validation
- JSON structure validation
- Required field checks

**Why this matters:**
- Workflows fail with cryptic errors on bad data
- API calls waste quota on invalid data
- Data corruption from unexpected formats

**Example:**

```json
// Add IF node before processing
{
  "type": "n8n-nodes-base.if",
  "parameters": {
    "conditions": {
      "boolean": [
        {
          "value1": "={{$json.email}}",
          "operation": "isNotEmpty"
        },
        {
          "value1": "={{$json.email}}",
          "operation": "matches",
          "value2": "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
        }
      ]
    }
  }
}
```

**Common Validations:**

**Email:**
```
^[^\s@]+@[^\s@]+\.[^\s@]+$
```

**Phone (US E.164):**
```
^\+1[0-9]{10}$
```

**URL:**
```
^https?:\/\/.+
```

**How to fix:**
1. Add IF node immediately after data input
2. Validate all required fields exist
3. Validate formats with regex
4. Route invalid data to error handler
5. Log validation failures for debugging

---

### ⚠️ P1-2: No Timeout Configurations

**What to check:**
- ALL HTTP Request nodes have timeout (default: 10000ms - 30000ms)
- Database queries timeout at 10000ms
- Long-running operations (Claude API) timeout at 60000ms
- File uploads timeout at 120000ms

**Why this matters:**
- Workflows hang indefinitely on slow APIs
- n8n execution slots filled with stuck workflows
- No way to recover from unresponsive services

**Examples:**

```json
// ❌ NO TIMEOUT - Can hang forever
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://api.example.com/slow-endpoint"
  }
}

// ✅ TIMEOUT SET - Fails after 30s
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://api.example.com/slow-endpoint",
    "options": {
      "timeout": 30000
    }
  }
}
```

**Recommended Timeouts:**
- Fast APIs (Twilio, SendGrid): 10000ms (10s)
- Standard REST APIs: 30000ms (30s)
- LLM APIs (OpenAI, Anthropic): 60000ms (60s)
- File uploads: 120000ms (2min)
- Database queries: 10000ms (10s)

**How to fix:**
1. Add timeout to all HTTP Request nodes
2. Match timeout to expected response time + buffer
3. Ensure error handling catches timeout errors

---

### ⚠️ P1-3: Hardcoded Values (Should Be Env Vars)

**What to check:**
- API base URLs
- Database connection strings
- Webhook endpoints
- Rate limit thresholds
- Retry counts
- Batch sizes

**Why this matters:**
- Can't change config without code changes
- Different values needed for dev/staging/prod
- Hard to maintain across multiple workflows

**Examples:**

```json
// ❌ HARDCODED BASE URL
{
  "url": "https://api.openai.com/v1/chat/completions"
}

// ✅ ENVIRONMENT VARIABLE
{
  "url": "={{$env.OPENAI_API_BASE_URL}}/chat/completions"
}

// ❌ HARDCODED RETRY COUNT
{
  "options": {
    "retry": {
      "maxRetries": 3
    }
  }
}

// ✅ CONFIGURABLE
{
  "options": {
    "retry": {
      "maxRetries": "={{$env.API_MAX_RETRIES || 3}}"
    }
  }
}
```

**How to fix:**
1. Move all configuration to environment variables
2. Document required env vars in README
3. Use sensible defaults with || operator
4. Create .env.example with all variables

---

### ⚠️ P1-4: Missing Retry Logic

**What to check:**
- External API calls have retry enabled
- Retry count: 3-5 attempts
- Wait between retries: 5000ms (5s)
- Exponential backoff for rate-limited APIs

**Why this matters:**
- Transient network errors cause workflow failures
- Rate limit errors could succeed on retry
- Manual re-execution wastes time

**Implementation:**

```json
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "={{$env.EXTERNAL_API_URL}}",
    "options": {
      "timeout": 30000,
      "retry": {
        "enabled": true,
        "maxRetries": 3,
        "waitBetween": 5000
      }
    }
  }
}
```

**When to use:**
- All external API calls
- Database operations
- File uploads/downloads
- Any network-dependent operation

**When NOT to use:**
- Idempotent operations that modify data (use with caution)
- Operations that charge per attempt
- Time-sensitive operations

**How to fix:**
1. Enable retry on HTTP Request nodes
2. Set appropriate retry count
3. Add delay between retries
4. Ensure operations are idempotent if retrying

---

## Tech Stack-Specific Rules

### **n8n Workflow JSON Structure**

**Required Top-Level Keys:**
```json
{
  "name": "Workflow Name",
  "nodes": [...],
  "connections": {...},
  "settings": {...}
}
```

**Node Requirements:**
- Node IDs must be unique UUIDs or sequential numbers
- All connections reference valid node IDs
- Position coordinates reasonable: [x: 0-10000, y: 0-5000]
- `typeVersion` matches installed n8n version (check n8n docs)

**Common Structure Issues:**
- Duplicate node IDs → P0 BLOCK
- Connections to non-existent nodes → P0 BLOCK
- Invalid position coordinates → P2 (cosmetic)

---

### **OpenAI API Integration**

```json
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "={{$env.OPENAI_API_BASE_URL}}/chat/completions",
    "method": "POST",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "options": {
      "timeout": 60000,
      "retry": {
        "enabled": true,
        "maxRetries": 2,
        "waitBetween": 5000
      }
    },
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "Bearer ={{$env.OPENAI_API_KEY}}"
        },
        {
          "name": "Content-Type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "model",
          "value": "gpt-4-turbo-preview"
        },
        {
          "name": "max_tokens",
          "value": 4096
        },
        {
          "name": "messages",
          "value": "={{$json.messages}}"
        },
        {
          "name": "temperature",
          "value": 0.7
        }
      ]
    }
  }
}
```

**Check for:**
- ✅ Model name is current (check OpenAI docs)
- ✅ max_tokens reasonable (≤ 16384 for GPT-4 Turbo)
- ✅ Messages array properly formatted
- ✅ Temperature between 0-1
- ✅ Timeout set to 60000ms minimum (LLMs can be slow)
- ✅ Authorization uses environment variable
- ✅ Error handling enabled
- ⚠️ Rate limiting respected (50-100 req/min depending on tier)

**Cost Monitoring:**
- GPT-4 Turbo: ~$0.01-0.03 per request
- Flag if workflow could make >100 requests
- Recommend usage tracking

---

### **Anthropic Claude API Integration**

```json
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "={{$env.ANTHROPIC_API_BASE_URL}}/messages",
    "method": "POST",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "x-api-key",
          "value": "={{$env.ANTHROPIC_API_KEY}}"
        },
        {
          "name": "anthropic-version",
          "value": "2023-06-01"
        },
        {
          "name": "Content-Type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "jsonBody": "={\n  \"model\": \"claude-3-5-sonnet-20241022\",\n  \"max_tokens\": 4096,\n  \"messages\": {{$json.messages}}\n}",
    "options": {
      "timeout": 60000
    }
  }
}
```

**Check for:**
- ✅ Uses `x-api-key` header (not Authorization)
- ✅ Includes `anthropic-version` header
- ✅ Model name is current (claude-3-5-sonnet-20241022)
- ✅ max_tokens ≤ 8192
- ✅ Timeout 60000ms minimum

---

### **Twilio SMS Integration**

```json
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "={{$env.TWILIO_API_URL}}/Accounts/={{$env.TWILIO_ACCOUNT_SID}}/Messages.json",
    "method": "POST",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpBasicAuth",
    "sendBody": true,
    "bodyContentType": "form-urlencoded",
    "bodyParameters": {
      "parameters": [
        {
          "name": "From",
          "value": "={{$env.TWILIO_PHONE_NUMBER}}"
        },
        {
          "name": "To",
          "value": "={{$json.patient_phone}}"
        },
        {
          "name": "Body",
          "value": "={{$json.message}}"
        }
      ]
    }
  }
}
```

**Check for:**
- ✅ Phone validation (E.164 format: +1XXXXXXXXXX)
- ✅ Message length ≤ 160 characters (or note if multi-part)
- ✅ Opt-out handling (STOP, UNSUBSCRIBE keywords)
- ✅ Time zone awareness (don't text at 2 AM)
- ✅ Rate limiting (respect Twilio limits)
- ⚠️ Cost tracking ($0.0075 per SMS)

**Phone Validation Pattern:**
```regex
^\+1[0-9]{10}$
```

**Time Zone Check:**
```json
{
  "type": "n8n-nodes-base.if",
  "parameters": {
    "conditions": {
      "boolean": [
        {
          "value1": "={{new Date().getHours()}}",
          "operation": "largerEqual",
          "value2": 9
        },
        {
          "value1": "={{new Date().getHours()}}",
          "operation": "smallerEqual",
          "value2": 18
        }
      ]
    }
  }
}
```

---

### **Supabase Database**

```json
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "={{$env.SUPABASE_URL}}/rest/v1/clinics",
    "method": "POST",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "apikey",
          "value": "={{$env.SUPABASE_ANON_KEY}}"
        },
        {
          "name": "Authorization",
          "value": "Bearer ={{$env.SUPABASE_SERVICE_KEY}}"
        },
        {
          "name": "Content-Type",
          "value": "application/json"
        },
        {
          "name": "Prefer",
          "value": "return=representation"
        }
      ]
    }
  }
}
```

**Check for:**
- ✅ Row Level Security (RLS) enabled on all tables
- ✅ Service key used only for privileged operations
- ✅ Anon key for read operations
- ✅ Connection pooling configured
- ✅ Proper error handling for unique constraints
- ⚠️ SQL injection prevention (use parameterized queries)

**RLS Verification:**
Must confirm in Supabase dashboard:
```sql
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public';
```

---

### **VAPI/Retell Voice AI**

```json
{
  "type": "n8n-nodes-base.webhook",
  "parameters": {
    "path": "vapi-callback",
    "httpMethod": "POST",
    "responseMode": "responseNode",
    "authenticate": true,
    "authenticationMethod": "headerAuth"
  }
}
```

**Check for:**
- ✅ Webhook signature validation
- ✅ Call duration tracking (avoid runaway costs)
- ✅ Graceful handling of call drops
- ✅ Recording storage configured
- ✅ Error handling for API failures
- ⚠️ Cost monitoring ($0.05-0.15 per minute)

**Call Duration Limit:**
```json
{
  "type": "n8n-nodes-base.if",
  "parameters": {
    "conditions": {
      "number": [
        {
          "value1": "={{$json.call_duration_seconds}}",
          "operation": "smaller",
          "value2": 600
        }
      ]
    }
  }
}
```

---

### **Apify Web Scraping**

```json
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "={{$env.APIFY_API_URL}}/acts/apify~google-maps-scraper/run-sync",
    "method": "POST",
    "authentication": "genericCredentialType",
    "options": {
      "timeout": 300000,
      "retry": {
        "enabled": true,
        "maxRetries": 1
      }
    },
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "Bearer ={{$env.APIFY_API_TOKEN}}"
        }
      ]
    },
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "queries",
          "value": "={{$json.search_query}}"
        },
        {
          "name": "maxResults",
          "value": 100
        }
      ]
    }
  }
}
```

**Check for:**
- ✅ Cost monitoring (Apify charges per compute unit)
- ✅ Proxy configuration (avoid IP bans)
- ✅ Rate limiting (respect Google's ToS)
- ✅ Result caching (don't re-scrape same data)
- ✅ Timeout appropriate for scraping (300000ms = 5min)
- ⚠️ Legal compliance (respect robots.txt)

---

### **Playwright Browser Automation**

```json
{
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "http://playwright:3000/scrape",
    "method": "POST",
    "options": {
      "timeout": 60000
    },
    "sendBody": true,
    "jsonBody": "={\n  \"url\": \"{{$json.target_url}}\",\n  \"wait_for\": \"#reviews-list\",\n  \"screenshot\": false\n}"
  }
}
```

**Check for:**
- ✅ Container connectivity (playwright service running)
- ✅ Page load timeouts configured
- ✅ Screenshot storage (if enabled, where saved?)
- ✅ Headless mode enabled
- ✅ Error handling for page load failures
- ⚠️ Resource cleanup (close browser after use)

---

## Code Quality (P2) - **NICE TO HAVE**

### 💡 Complex Functions

**Issue:** Functions > 50 lines in Code nodes

**Impact:** Hard to debug, maintain, test

**Fix:** Split into multiple Code nodes or use Sub-workflows

---

### 💡 Naming Conventions

**Best Practices:**
- Node names should be descriptive: "Scrape Google Reviews" not "HTTP Request 1"
- Variables use snake_case: `patient_email` not `patientEmail`
- Constants use UPPER_CASE: `MAX_RETRIES`, `API_BASE_URL`
- Workflow names: descriptive and unique

**Examples:**

```json
// ❌ POOR NAMING
{
  "name": "HTTP Request",
  "type": "n8n-nodes-base.httpRequest"
}

// ✅ GOOD NAMING
{
  "name": "OpenAI - Analyze Review Sentiment",
  "type": "n8n-nodes-base.httpRequest"
}
```

---

### 💡 Documentation

**Should include:**
- Sticky notes for major workflow sections
- Comments in Code nodes explaining complex logic
- README in workflow folder explaining purpose
- Links to relevant API documentation

---

## n8n-Specific Best Practices

### **Workflow Structure**

**Standard Pattern:**
```
Trigger → Validate → Process → Branch (Success/Error) → Store → Notify
```

**Visual Organization:**
- Group related nodes visually
- Consistent spacing (250px horizontal, 100px vertical)
- Main flow left-to-right
- Error handling branches below
- Logging/monitoring nodes at bottom

---

### **Performance Optimization**

**Parallel Processing:**
```json
{
  "type": "n8n-nodes-base.splitInBatches",
  "parameters": {
    "batchSize": 10,
    "options": {
      "reset": false
    }
  }
}
```

**Best Practices:**
- Use `splitInBatches` for parallel processing (batch size: 10)
- Add `wait` nodes to respect rate limits
- Cache API responses when possible
- Use database indexes for queries

---

### **Error Handling Patterns**

**Pattern 1: Continue On Fail**
```
HTTP Request → (continueOnFail: true) → IF Node (check success) → Success Path / Error Path
```

**Pattern 2: Error Branch**
```
HTTP Request → Success Output → Continue
              → Error Output → Log Error → Notify Admin
```

**Pattern 3: Retry Logic**
```
HTTP Request → options.retry.maxRetries: 3 → exponentialBackoff
```

---

## Never Flag These (False Positives)

### ✅ n8n Workflow JSON Structure

```json
{
  "nodes": [...],
  "connections": {...},
  "settings": {...}
}
```

This is REQUIRED n8n format, not a mistake.

---

### ✅ Long Node Names

```
"Google Maps → Playwright → Parse → Validate → Store"
```

n8n auto-generates these for workflow readability, not a code quality issue.

---

### ✅ "Unused" Variables in Expressions

```javascript
={{$json.clinic_data.reviews}}
```

Variables ARE used in n8n expressions, just not standard JavaScript.

---

### ✅ Sequential Operations That MUST Be Sequential

Some operations cannot be parallelized:
- Database transactions (must be sequential)
- Stateful operations (auth token → use token)
- Order-dependent operations (create parent → create child)

Don't flag these as "could be parallel".

---

## Review Process

### **Step 1: Structure Validation**
- [ ] Valid JSON syntax
- [ ] All required top-level keys present
- [ ] No duplicate node IDs
- [ ] All connection references valid

### **Step 2: Security Scan**
- [ ] No hardcoded credentials
- [ ] All env variables documented
- [ ] Webhook authentication configured
- [ ] No PHI in logs (HIPAA compliance)

### **Step 3: Error Handling Review**
- [ ] Every external API call has error handling
- [ ] Every database operation has error handling
- [ ] Every webhook has validation
- [ ] Timeouts configured everywhere

### **Step 4: Tech Stack Validation**
- [ ] OpenAI: Model, tokens, headers correct
- [ ] Twilio: Phone format, opt-out, time zones
- [ ] Supabase: RLS, keys, connection pooling
- [ ] VAPI: Webhook signature, call tracking
- [ ] Apify: Cost monitoring, rate limiting
- [ ] Playwright: Container connectivity, timeouts

### **Step 5: Quality Assessment**
- [ ] Node naming is descriptive
- [ ] Workflow structure is logical
- [ ] Performance optimizations applied
- [ ] Documentation is complete

---

## Example Review Output

### 🔴 Critical Issues (P0)

**Node 8: HTTP Request - OpenAI API**
- **Issue**: Missing error handling branch
- **Impact**: Workflow crashes if OpenAI returns 429 (rate limit)
- **Fix**: Add error branch to Node 40 (Error Logger)
  ```json
  {
    "continueOnFail": true,
    "onError": "continueRegularOutput"
  }
  ```

**Node 15: Webhook - Patient Intake**
- **Issue**: No authentication configured
- **Impact**: CRITICAL SECURITY - Anyone can submit fake patient data
- **Fix**: Enable headerAuth with secret token
  ```json
  {
    "authenticate": true,
    "authenticationMethod": "headerAuth"
  }
  ```

**Node 22: Supabase Insert - Patient Records**
- **Issue**: Hardcoded API key in authorization header
- **Impact**: API key exposed in workflow JSON - SEVERE SECURITY RISK
- **Fix**: Use environment variable
  ```json
  {
    "value": "Bearer ={{$env.SUPABASE_SERVICE_KEY}}"
  }
  ```

---

### ⚠️ Important Issues (P1)

**Node 12: IF Node - Email Validation**
- **Issue**: No null check before regex validation
- **Impact**: Workflow fails with undefined email
- **Fix**: Add null check condition first

**Node 18: HTTP Request - Twilio SMS**
- **Issue**: No timeout configured
- **Impact**: Workflow hangs if Twilio API slow
- **Fix**: Add 10s timeout

---

### 💡 Suggestions (P2)

**Nodes 10-12: Sequential API Calls**
- **Suggestion**: These could run in parallel for 3x speedup
- **How**: Use splitInBatches to process concurrently

**Overall Workflow**
- **Suggestion**: Add monitoring dashboard
- **How**: Connect to Grafana for real-time metrics

---

## Success Metrics

Codex review is successful when:
- ✅ Zero P0 (Critical) issues
- ✅ < 3 P1 (Important) issues
- ✅ All environment variables documented
- ✅ All external APIs have error handling
- ✅ No security vulnerabilities
- ✅ HIPAA compliance verified (if applicable)

---

## Continuous Improvement

After each review:
1. **Log common mistakes** → Update this guide
2. **Track issue frequency** → Prioritize prevention
3. **Measure fix time** → Optimize guidance
4. **Collect feedback** → Refine criteria

---

**Last Updated:** Auto-updated via GitHub Actions
**Review Count:** Tracked via Prometheus/Grafana
**Average Issues per PR:** Calculated from review history

---

*This file is the source of truth for all automated code reviews in this repository. Changes to review criteria should be made here and will be reflected in future Codex reviews.*
