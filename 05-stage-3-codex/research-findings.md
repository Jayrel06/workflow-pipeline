# Research Findings: n8n Best Practices & Codex Integration
**Date:** January 11, 2025
**Purpose:** Research for Codex GitHub PR review automation integration

---

## 🔍 Research Summary

### Sources Analyzed:
- **n8n Official Documentation** (2025)
- **Context7 MCP** - Real-time n8n node documentation
- **Web Search** - Latest best practices and patterns
- **OpenAI Codex Documentation** - GitHub Actions integration

---

## 📚 Part 1: n8n Workflow Best Practices (2025)

### 1. **Centralized Error Handling**

**Professional Standard:**
- Create a single, centralized Error Workflow acting as "Mission Control"
- Use Error Trigger node as the workflow start
- One error workflow can service multiple production workflows

**Critical for AGENTS.md:**
- Flag workflows WITHOUT centralized error handling
- P0 issue if production workflow has no error workflow configured

### 2. **Automatic Retry Mechanisms**

**Best Practice:**
- Enable "Retry On Fail" on all nodes calling external APIs
- Recommended: 3-5 retry attempts
- Add 5-second delay between retries to avoid overwhelming services

**From n8n HTTP Request Node Documentation:**
```json
{
  "options": {
    "retry": {
      "enabled": true,
      "maxRetries": 3,
      "waitBetween": 5000
    }
  }
}
```

**Critical for AGENTS.md:**
- Flag external API calls without retry configuration
- P1 issue (should fix, not critical)

### 3. **Error Branching Patterns**

**Pattern 1: Continue On Fail**
```json
{
  "continueOnFail": true,
  "onError": "continueRegularOutput"
}
```

**Pattern 2: Error Output Routing**
- Enable "Continue using error output" option
- Route to alternative path from error output
- Allows workflow to handle failures gracefully

**Critical for AGENTS.md:**
- Review every HTTP Request, database query, and external call
- Ensure error path exists OR continueOnFail enabled

### 4. **Webhook Security (From n8n Webhook Documentation)**

**Supported Authentication Methods:**
- Basic Auth
- Header Auth
- JWT Auth
- None (⚠️ DANGEROUS for production)

**Maximum Payload:** 16MB (default)
- Self-hosted can configure via `N8N_PAYLOAD_SIZE_MAX`

**Critical for AGENTS.md:**
- P0 CRITICAL: Flag ANY webhook with "Authentication: None"
- Require Header Auth or Basic Auth minimum
- Document webhook secret token requirements

**Example Secure Webhook:**
```json
{
  "type": "n8n-nodes-base.webhook",
  "parameters": {
    "authentication": "headerAuth",
    "authenticationMethod": "headerAuth"
  },
  "credentials": {
    "httpHeaderAuth": {
      "id": "{{credential_id}}",
      "name": "Webhook Secret"
    }
  }
}
```

### 5. **HTTP Request Node Best Practices**

**From Official n8n Documentation:**

**Required Options:**
- **Timeout**: Always set (default: 10000ms for standard APIs, 60000ms for LLMs)
- **Response > Never Error**: Consider for workflows that need to continue regardless
- **Response > Include Response Headers and Status**: Enable for debugging

**Authentication Priority:**
1. Use "Predefined Credential Type" when available
2. Only use "Generic Credential Type" when necessary
3. NEVER hardcode credentials in parameters

**Critical for AGENTS.md:**
- Flag HTTP Request nodes without timeout
- Flag nodes using hardcoded authentication
- Require environment variables: `={{$env.API_KEY}}`

### 6. **Data Validation with IF Node**

**From n8n IF Node Documentation:**

**Validation Pattern:**
```json
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

**Best Practice:**
- Add IF node BEFORE processing user input
- Validate null/undefined before using data
- Use "matches" operation for regex validation (email, phone, etc.)

**Critical for AGENTS.md:**
- Flag workflows accepting user input without validation
- P1 issue (should fix)

### 7. **Version Control & Monitoring**

**2025 Best Practices:**
- Use Git for n8n workflow version control
- Implement monitoring with alerting (email, Slack)
- Build logic into Error Workflow using Switch node for severity

**Example Alert Logic:**
```
Error Trigger → Switch (workflow name) → Critical: @channel Slack + Phone push
                                       → Non-critical: Email only
```

---

## 🤖 Part 2: GitHub Codex Integration Best Practices

### 1. **Official OpenAI Codex Action**

**Repository:** `openai/codex-action`

**Key Features:**
- Run Codex from GitHub Actions workflow
- Tight privilege control
- Apply patches directly
- Post reviews on PRs

**Use Cases:**
- CI/CD job participation
- Automated patch application
- Straight-from-workflow reviews

### 2. **Sample Workflow Structure**

**Pattern Found:**
```yaml
name: Codex Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Codex Review
        uses: openai/codex-action@v1
        with:
          prompt-file: .github/codex-prompt.md

      - name: Post Review
        uses: actions/github-script@v7
        with:
          script: |
            // Post Codex output as comment
```

**Critical for our implementation:**
- Use `@codex` tagging mechanism
- Wait for response (90-120 seconds typical)
- Parse response for severity markers
- Block merge on P0 issues

### 3. **Codex /review Command**

**API Mode Available:**
- Programmatic control via API
- CI/CD pipeline integration
- Structured feedback format
- Merge guidance automation

**Training Focus (GPT-5-Codex):**
- Correctness issues
- Performance problems
- Security vulnerabilities
- Maintainability concerns
- Developer experience issues

**Critical for AGENTS.md:**
- Structure review output matching Codex's training
- Use P0/P1/P2 severity levels
- Focus on actionable issues only
- Don't flag style issues unless impactful

### 4. **Safety & Permissions**

**Best Practices:**
- Limit Codex GitHub permissions
- Run in isolated environment
- Review generated patches before applying
- Use separate staging branch for Codex changes

### 5. **Integration Patterns**

**Pattern 1: Comment-Triggered Review**
```yaml
on:
  issue_comment:
    types: [created]

jobs:
  codex-review:
    if: contains(github.event.comment.body, '@codex')
    # Run review
```

**Pattern 2: Automatic on PR**
```yaml
on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - '**/*.json'
      - '**/*.js'
```

**Pattern 3: Scheduled Reviews**
```yaml
on:
  schedule:
    - cron: '0 9 * * 1'  # Weekly Monday 9am
```

**For our implementation:** Use Pattern 2 (automatic on PR with path filters)

---

## 🎯 Part 3: Key Takeaways for AGENTS.md

### Critical Issues (P0) - Must Include:

1. **Missing Error Handling**
   - Every external API call
   - Every database operation
   - Every webhook trigger

2. **Hardcoded Credentials**
   - Detect patterns: `"apiKey": "sk-..."`, `"password": "..."`
   - Require: `={{$env.VARIABLE}}`

3. **Unsafe Webhooks**
   - Authentication MUST be enabled
   - Minimum: Header Auth or Basic Auth
   - Document webhook secrets

4. **Missing Timeouts**
   - All HTTP Request nodes
   - Default: 10000ms (10s) for APIs
   - 60000ms (60s) for LLMs like Claude

5. **No Input Validation**
   - User-provided data MUST be validated
   - Email, phone, JSON structure
   - Null/undefined checks

### Important Issues (P1) - Should Fix:

1. **Missing Retry Logic**
   - External APIs should have retry enabled
   - 3-5 attempts with 5s delay

2. **No Data Validation**
   - IF nodes before processing
   - Regex validation for formats

3. **Hardcoded Values**
   - URLs, connection strings
   - Rate limits, thresholds
   - Should be environment variables

### Code Quality (P2) - Nice to Have:

1. **Performance Optimization**
   - Parallel vs sequential operations
   - Batch processing opportunities

2. **Naming Conventions**
   - Descriptive node names
   - Clear variable names

3. **Documentation**
   - Sticky notes for complex logic
   - README explaining workflow

---

## 📊 Part 4: n8n Node Documentation Reference

### HTTP Request Node
- **Purpose:** Make HTTP requests to REST APIs
- **Critical Settings:** Timeout, Retry, Error Handling, Authentication
- **Common Issues:** Missing error handling, no timeout, hardcoded auth

### Webhook Node
- **Purpose:** Receive data from external services
- **Critical Settings:** Authentication method, Response mode, Path
- **Common Issues:** No authentication, unclear paths, missing validation
- **Max Payload:** 16MB default

### IF Node
- **Purpose:** Conditional workflow splitting
- **Critical Settings:** Data type, comparison operations, combining conditions
- **Use Cases:** Input validation, null checks, regex matching

---

## ✅ Validation Against Context7 MCP

All findings validated against real-time n8n documentation (Context7 MCP):
- ✅ HTTP Request node parameters confirmed
- ✅ Webhook authentication methods confirmed
- ✅ IF node comparison operations confirmed
- ✅ Error handling patterns validated
- ✅ Best practices align with official docs

---

## 🚀 Implementation Plan for AGENTS.md

Based on research, AGENTS.md will include:

1. **800+ lines** of comprehensive review guidelines
2. **Tech stack specific rules** (OpenAI, Twilio, Supabase, VAPI, Apify, Playwright)
3. **Real examples** from n8n documentation
4. **Detection patterns** for common issues
5. **Fix templates** for each issue type
6. **Never flag these** section to avoid false positives

---

**Research Phase Complete** ✅
**Next Phase:** Create AGENTS.md with these findings
