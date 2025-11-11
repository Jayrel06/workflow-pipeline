# Workflow Name
PT Clinic Intelligence & Outreach System

## Business Context

**What problem does this solve?**
Small physical therapy clinics are losing revenue due to operational inefficiencies that show up in public reviews: missed calls, scheduling chaos, poor communication. Traditional cold outreach gets <1% response because it's generic. We need to build an intelligent research engine that:

1. **Discovers real problems** by analyzing public data (Google Reviews, websites)
2. **Finds decision-makers** using free scraping techniques (no paid APIs)
3. **Creates evidence-based outreach** that references specific pain points
4. **Tracks everything** in a CRM pipeline for follow-up

**Who is this for?**
CoreReceptionAI - An AI consulting firm positioning as premium consultants, not vendors. Target: PT clinic owners/managers with 1-3 locations, $500K-$3M revenue, who are tech-aware enough to adopt AI solutions.

**Why is this needed now?**
Pre-revenue stage. Need first 3 clients. Manual research takes 40-60 hours per 100 clinics and yields 0.5% response rates. This system must achieve 5-10% response rates through hyper-personalization while reducing research time to <1 hour per 100 clinics.

**Success Criteria**:
- **Quality Over Quantity**: Better to research 20 clinics thoroughly than 100 superficially
- **Evidence-Based**: Every outreach must reference specific, real pain points
- **Consultant Positioning**: Never sound like a salesperson or use generic AI hype
- **Production Reliability**: Must run daily without manual intervention

---

## System Architecture Overview

### Core Philosophy: Intelligent Waterfall Strategy

This isn't a simple scraper. It's a multi-stage intelligence pipeline where each stage enriches data, and failures at one stage gracefully degrade to fallbacks without losing the lead.

**Stage Flow**:
Discover (Google Maps) ↓ Analyze Pain (Google Reviews) ↓ Enrich Contact (Website → Business Profile → Pattern Generation) ↓ Score & Prioritize (AI Analysis) ↓ Generate Outreach (Evidence-Based Email) ↓ Store & Alert (Supabase + Gmail)


**Key Architectural Principles**:
1. **Fail Forward**: If email scraping fails, try pattern generation. If that fails, save the lead anyway.
2. **Async Everything**: Webhook responds instantly, all processing happens in background
3. **Data First**: Store raw data first (reviews, contact info), then analyze
4. **Evidence Trail**: Every analysis must trace back to specific data sources
5. **Human-in-Loop**: A-tier leads get immediate notifications for human review before sending

---

## Trigger Information

**Primary Trigger: Webhook (Interactive Use)**
- Path: `/webhook/pt-clinic-research/{random_string}`
- Method: POST
- Accepts: `{ "city": "Austin", "state": "TX", "count": 20 }`
- Response: Immediate 202 Accepted with execution ID
- Use Case: On-demand research for specific cities

**Secondary Trigger: Schedule (Automated Operation)**
- Cron: `0 9,13,17,21 * * *` (4x daily at 9am, 1pm, 5pm, 9pm)
- Auto-cycles through cities: ["Miami, FL", "Austin, TX", "Denver, CO", "Portland, OR"]
- Processes 20 clinics per run = 80 clinics/day capacity
- Use Case: Continuous lead generation pipeline

**Design Requirements**:
- Webhook must return immediately (< 2 seconds) - processing is async
- Schedule should handle timezone correctly (based on business hours)
- Both triggers must prevent duplicate processing (check last processed timestamp)

---

## Data Flow & Processing Stages

### Stage 1: Discovery - Find Clinics (Playwright + Google Maps)

**Objective**: Get a list of PT clinics in a specific city with basic business info

**Input**: City, State, Count
**Tool**: Playwright container (HTTP API to scraping service)
**Output**: Array of clinic objects with basic data

**What to Extract**:
- Business name (exact as shown on Google)
- Full address (for uniqueness checking)
- Phone number (primary contact method)
- Website URL (for email scraping)
- Google Place ID (unique identifier)
- Star rating + review count (quality indicators)
- Direct Google Maps URL (for review scraping)

**Critical Requirements**:
1. **Uniqueness**: Use Place ID as primary key - never process same clinic twice
2. **Data Quality**: Validate phone format (10 digits), website is valid URL
3. **Scraping Ethics**: 2-second delay between requests, rotate user agents
4. **Error Handling**: If Google blocks (CAPTCHA), wait 60 seconds and retry with different agent

**Success Metrics**:
- Find at least 80% of requested count (if asking for 20, get 16+)
- <5% data quality issues (invalid phones, missing critical fields)
- Zero Google IP bans (respectful scraping is mandatory)

---

### Stage 2: Pain Point Discovery (Playwright + Google Reviews)

**Objective**: Extract customer complaints that reveal operational problems

**Input**: Clinic object from Stage 1
**Tool**: Playwright container → Google Reviews section
**Output**: Array of reviews, focused on 1-3 star complaints

**What to Extract from Each Review**:
- Reviewer first name only (privacy - no last names)
- Star rating (1-5)
- Review text (full content - this is where pain lives)
- Date posted (relative is fine - "2 weeks ago")
- Review ID (for deduplication)

**Critical Requirements**:
1. **Quality Over Quantity**: Get 20-30 most recent reviews, prioritize low ratings
2. **Full Text**: Many reviews hide behind "Read more" - must expand to get complete complaints
3. **Recency Bias**: Sort by "Newest" not "Most Relevant" - recent pain is actionable
4. **Graceful Degradation**: If no reviews, mark `reviews_available: false` and continue

**What Makes Good Pain Point Data**:
- Specific complaints, not generic praise
- Operational issues (phones, scheduling, staff) not clinical quality
- Recent (last 90 days preferred)
- Multiple patients mentioning same issue = pattern

**Success Metrics**:
- 80%+ of clinics have review data extracted
- Average 15+ reviews per clinic with reviews
- At least 30% are 1-3 star (these contain pain)

---

### Stage 3: Contact Enrichment (Multi-Source Waterfall)

**Objective**: Get a valid email address for the decision-maker using FREE methods

**Why This Is Critical**: Without email, we can't do outreach. This stage has multiple fallback strategies to maximize success rate.

#### 3a: Website Email Scraping (Primary Method)
**Input**: Clinic with website URL
**Tool**: Playwright → website contact page
**Strategy**:
- Visit homepage, look for "Contact", "About Us", "Team" links
- Extract all email addresses from page
- Prioritize by pattern: owner@ > manager@ > first-name@ > info@ > contact@
- Take top 3 emails found

**Success Rate Expected**: 60-70% of clinics with websites

#### 3b: Google Business Profile Owner Extraction (Secondary Method)
**Input**: Clinics without email from 3a
**Tool**: Playwright → Google Maps "About" section
**Strategy**:
- Check if business profile shows "Owned by [Name]"
- Extract owner name
- Split into first_name, last_name
- Extract domain from website URL
- Generate likely email patterns for next stage

**Success Rate Expected**: 30-40% of remaining clinics

#### 3c: Email Pattern Generation + SMTP Verification (Tertiary Method)
**Input**: Clinics with domain and optionally owner name
**Tool**: n8n Email node in validation mode
**Strategy**:
- Generate 5-7 common patterns:
  - `info@domain.com` (most common)
  - `contact@domain.com` (second most common)
  - `admin@domain.com` (management)
  - `[first]@domain.com` (if name known)
  - `[first].[last]@domain.com` (if name known)
- For each pattern, test SMTP without sending (verify address exists)
- First valid pattern becomes primary_email

**Success Rate Expected**: 40-50% of remaining clinics

**Overall Contact Enrichment Goal**: 70-80% of all clinics should have a valid email

**Critical Requirements**:
1. **Never Skip**: Even if email fails, save the lead (we have phone number)
2. **Source Attribution**: Always mark how email was obtained for confidence scoring
3. **Verification**: SMTP-verified emails are higher confidence than scraped
4. **Privacy**: Never scrape personal emails (gmail, yahoo, etc.) - business only

---

### Stage 4: Pain Point Analysis (Claude API)

**Objective**: Transform raw reviews into structured, actionable pain intelligence

**Input**: Clinic object with reviews array
**Tool**: Python-AI container → Claude API
**Output**: Structured pain analysis with evidence

**What Claude Should Analyze**:

1. **Categorize Pain Points** into 6 buckets:
   - **Phone Issues**: Can't reach, no callback, voicemail full
   - **Scheduling**: Online booking broken, long wait times, cancellation issues
   - **Billing**: Insurance confusion, surprise charges, payment hassles
   - **Communication**: Poor follow-up, staff not returning calls/messages
   - **Staff**: Rudeness, turnover, inexperienced front desk
   - **Technology**: Outdated systems, manual processes, paper-based

2. **For Each Category** extract:
   - Specific evidence quotes (with reviewer first names)
   - Severity score (1-10, how bad is this problem?)
   - Frequency count (how many patients mentioned it?)

3. **Generate Summary**:
   - Top pain point (the #1 most severe issue)
   - Evidence summary (2-3 sentences with specific examples)
   - Confidence score (1-10, based on data quality and consistency)

**Critical Requirements**:
1. **Evidence-Based Only**: Never infer problems not mentioned in reviews
2. **Quote Attribution**: Always include "Sarah M. said..." format for credibility
3. **Operational Focus**: Ignore clinical complaints (treatment quality) - we solve operational pain
4. **Confidence Scoring**: Low review count (<10) = low confidence, high count (50+) + consistent complaints = high confidence

**Quality Criteria**:
- Evidence quotes must be EXACT text from reviews (not paraphrased)
- Severity scores must correlate with frequency and intensity of complaints
- Summary must be specific enough to use in email ("7 patients complained about phones" not "communication issues")

**Success Metrics**:
- 90%+ of clinics with reviews get pain analysis
- 70%+ have confidence score ≥6 (usable intelligence)
- Top pain identified in 85%+ of analyses

---

### Stage 5: Lead Scoring & Prioritization

**Objective**: Rank leads by likelihood to convert and revenue potential

**Input**: Fully enriched clinic object
**Tool**: n8n Function node (scoring algorithm)
**Output**: Score 1-10 and tier A/B/C

**Scoring Factors** (additive):

**Contact Quality** (0-5 points):
- Has verified email: +3
- Has phone: +1
- Has website: +1

**Business Size Indicators** (0-3 points):
- Review count >50: +2 (established business)
- Review count >100: +3 (significant operation)
- Rating <4.0: +1 (pain-aware customers)

**Pain Intelligence** (0-5 points):
- Pain confidence ≥8: +3 (strong evidence)
- Pain confidence 6-7: +2 (moderate evidence)
- High-severity phone/scheduling issues: +2 (perfect fit for our solution)

**Tier Assignment**:
- A-tier: Score 8-10 (immediate outreach, human review)
- B-tier: Score 6-7 (outreach, less urgent)
- C-tier: Score 1-5 (nurture, low priority)

**Critical Requirements**:
1. **Conservative Scoring**: Better to under-promise and over-deliver
2. **Transparent Logic**: Every score must be explainable to humans
3. **Tie-Breaker**: If tied, prefer more recent reviews (recency = actionability)

---

### Stage 6: Email Generation (Claude API - Conditional)

**Objective**: Create hyper-personalized outreach that doesn't sound like spam

**When to Run**: Only for A-tier and B-tier leads that have:
- Valid email address
- Pain analysis with confidence ≥6
- At least 3 evidence quotes

**Input**: Enriched clinic object
**Tool**: Python-AI container → Claude API
**Output**: Subject line + email body

**Email Writing Instructions for Claude**:

**Positioning**:
- You're a consultant who did research, NOT a salesperson
- Lead with evidence, not with sales pitch
- Demonstrate domain expertise (you understand PT clinic operations)
- Position solution as natural fix for their specific problem

**Structure** (150 words max):
1. **Hook**: Specific observation from research ("I noticed 7 patients mentioned...")
2. **Evidence**: Quote 1-2 specific reviewers by name
3. **Insight**: What this means for their business (revenue loss, patient churn)
4. **Solution Hint**: Brief mention of how you solve this (AI phone system, automated scheduling)
5. **Soft CTA**: Ask for 15-minute conversation, not a demo

**Style Requirements**:
- Conversational, not corporate
- Confident but humble
- No AI hype words (revolutionary, game-changing, cutting-edge)
- No generic templates (every email must feel custom-researched)
- Professional but warm (you're helping, not selling)

**Example Tone**:
❌ Bad: "Our revolutionary AI platform transforms PT clinic operations..."
✅ Good: "I noticed 7 patients mentioned phone issues at your clinic. Sarah M. said she 'called 5 times without callback.' Since you use WebPT, I've built AI phone systems that integrate directly and handle booking automatically. Would 15 minutes this week work to discuss?"

**Critical Requirements**:
1. **Evidence First**: Must reference specific reviewers and complaints
2. **No Generic Claims**: Never say "many clinics struggle with..." - reference THEIR struggles
3. **Tech Integration**: If you can identify their EMR system from website, mention integration
4. **Subject Line**: Must be specific, not clickbait ("Your phone system is losing patients" not "Let's talk AI")

**Success Metrics**:
- 100% of generated emails include specific evidence quotes
- 0% use generic AI marketing language
- Subject lines are personalized to clinic's top pain point

---

### Stage 7: Data Persistence (Supabase)

**Objective**: Store all intelligence in structured database for CRM workflow

**Tool**: n8n HTTP Request → Supabase REST API
**Operations**: Upsert (update if exists, insert if new)

**Database Design Requirements**:

**Primary Table: `pt_clinic_leads`**
- Use `place_id` as unique identifier (Google's ID)
- Store complete enrichment chain (raw data + analysis)
- JSONB fields for flexible schema (reviews, pain_analysis, emails_found)
- Status tracking (new → contacted → responded → qualified → closed)
- Timestamps for everything (created, updated, contacted, responded)

**Related Table: `email_drafts`**
- Links to clinic via foreign key
- Stores generated emails before sending
- Tracks sending/opening/reply status
- Allows A/B testing different versions

**Execution Tracking Table: `workflow_executions`**
- Logs every research run
- Stores input params (city, count)
- Records results (clinics found, emails generated, errors)
- Enables analytics dashboard

**Critical Requirements**:
1. **Idempotency**: Running same city twice should UPDATE existing records, not duplicate
2. **Immutable History**: Never delete data, only mark status changes
3. **Query Performance**: Index on tier, status, city, created_at for dashboard queries
4. **Data Integrity**: Foreign keys, check constraints, sensible defaults

**Backup Strategy**:
- Primary: Supabase (Postgres)
- Fallback: Google Sheets (if Supabase completely down)
- Emergency: Gmail notification with attached JSON (last resort)

---

### Stage 8: Notification & Alerting (Gmail)

**Objective**: Get A-tier leads in front of human immediately, summarize daily activity

**Notification Types**:

#### 1. Immediate A-Tier Lead Alert
**Trigger**: Clinic scored 8-10 with email generated
**Sent To**: Human operator (jason@company.com)
**Contents**:
- Clinic name, location, contact info
- Top pain point with evidence summary
- Lead score breakdown (why A-tier?)
- Generated email (ready to review and send)
- Links to: Supabase record, Google Maps listing
**Timeline**: Within 60 seconds of discovery

#### 2. Daily Summary Report
**Trigger**: All clinics in run processed
**Sent To**: Human operator
**Contents**:
- Research summary (city, count, time taken)
- Lead distribution (X A-tier, Y B-tier, Z C-tier)
- Top 3 pain points found across all clinics
- Email generation success rate
- Next scheduled research run
**Timeline**: Immediately after run completion

#### 3. Error Alerts (Critical Only)
**Trigger**: System-level failure (Playwright down, Supabase unreachable)
**Sent To**: Human operator
**Contents**:
- What failed, error details
- How many clinics affected
- Manual action needed
- System recovery status
**Timeline**: Immediately upon detection

**Critical Requirements**:
1. **Action-Oriented**: Every notification must tell human exactly what to do next
2. **Context-Rich**: Include all info needed to act (don't make human look up data)
3. **Prioritized**: A-tier alerts are urgent, daily summaries are FYI
4. **Mobile-Friendly**: Format emails for phone viewing (short paragraphs, clear headers)

---

## Error Handling Philosophy

### Fail Forward, Never Silent

**Principle**: Every error has 3 possible outcomes:
1. **Retry and succeed** → Log for monitoring, continue normally
2. **Graceful degradation** → Save partial data, continue without failed component
3. **Hard stop + alert** → Critical failure, human intervention required

**Error Categories**:

#### Minor Errors (Log Only)
- Single website scrape fails → Try next clinic
- Email pattern doesn't verify → Try next pattern
- Review scrape gets partial data → Use what we have

**Action**: Log to database, continue processing

#### Moderate Errors (Degrade Gracefully)
- Pain analysis fails for one clinic → Save clinic without analysis
- Email generation fails → Save clinic, mark for manual email later
- Some enrichment steps fail → Save clinic with partial data

**Action**: Log error, mark clinic status, continue workflow

#### Critical Errors (Stop and Alert)
- Playwright container completely down → Can't discover clinics
- Supabase unreachable AND Google Sheets unavailable → Nowhere to save data
- Claude API exhausted quota → Can't analyze or generate

**Action**: Send immediate Gmail alert, pause scheduled runs, log for investigation

**Never Do**:
- ❌ Silently skip errors
- ❌ Retry infinitely (max 3 attempts per operation)
- ❌ Fail entire workflow because one clinic failed
- ❌ Lose data due to storage failure (always have backup)

---

## Performance & Quality Requirements

### Speed Targets

**Per Clinic Processing**:
- Discovery: 3-5 seconds (Google Maps scrape)
- Review extraction: 10-15 seconds (if 30 reviews)
- Website scrape: 5-10 seconds (if website exists)
- Pain analysis: 5-10 seconds (Claude API call)
- Email generation: 5-8 seconds (Claude API call)
- **Total per clinic**: 60-90 seconds average

**Per Batch (20 clinics)**:
- Serial processing: ~30 minutes
- With parallelization: ~20 minutes (Playwright can handle 3-5 concurrent)
- **Target**: <25 minutes per batch

**Daily Throughput**:
- 4 runs/day × 20 clinics = 80 clinics/day
- 560 clinics/week
- 2,400 clinics/month capacity

### Quality Targets

**Data Quality**:
- 80%+ email enrichment success rate
- 90%+ pain analysis completion (for clinics with reviews)
- 95%+ data accuracy (correct phones, addresses, emails)
- 0% duplicates (Place ID uniqueness enforced)

**Intelligence Quality**:
- 70%+ of pain analyses have confidence ≥6
- 85%+ of generated emails include specific evidence
- 100% of A-tier leads have human-reviewable quality

**System Reliability**:
- 99% uptime (few hours downtime/month acceptable)
- <1% data loss rate (backup strategies prevent this)
- 100% of errors logged and traceable

---

## Success Metrics (Month 1 Targets)

### Volume Metrics
- **Clinics Researched**: 500+ (20/day × 25 business days)
- **Emails Enriched**: 350+ (70% success rate)
- **A-Tier Leads**: 50+ (10% of researched)

### Engagement Metrics
- **Email Open Rate**: 30-50% (personalization increases opens)
- **Response Rate**: 5-10% (25-50 replies)
- **Meetings Booked**: 10-15 (2-3% of researched convert to meetings)

### Business Impact
- **Deals Closed**: 5-10 (1-2% of researched)
- **Revenue**: $25K-$150K ($5K-$15K per deal)
- **System Cost**: ~$200-300/month (APIs, infrastructure)
- **ROI**: 50-300x return on investment

### Comparison to Manual Process
- **Time Saved**: 1,000+ hours (40-60hrs manual vs 1hr automated per 100 clinics)
- **Response Rate**: 10-20x improvement (0.5% → 5-10%)
- **Cost Per Lead**: 95% reduction ($50/lead manual → $2/lead automated)

---

## Integration Architecture

### Tool Stack (All FREE Tier)

**Scraping Layer**:
- Playwright container (self-hosted or browserless.io free tier)
- Handles: Google Maps, Google Reviews, Website scraping
- HTTP API: POST requests with scraping instructions

**AI Processing Layer**:
- Claude API via Python-AI container
- Handles: Pain point analysis, email generation
- REST API: Anthropic Messages API

**Data Layer**:
- Supabase (free tier: 500MB database, 2GB bandwidth)
- Handles: Primary data storage, CRM tracking
- REST API: Standard Postgres over HTTP

**Orchestration Layer**:
- n8n (self-hosted)
- Handles: Workflow logic, scheduling, error handling
- Coordinates all components

**Communication Layer**:
- Gmail via MCP or OAuth
- Handles: Notifications, alerts, reports
- API: Gmail API or MCP interface

### Data Flow Integration Points

1. **Webhook → n8n** (HTTP POST)
2. **n8n → Playwright** (HTTP POST for scraping)
3. **n8n → Claude API** (HTTP POST for analysis)
4. **n8n → Supabase** (HTTP GET/POST/PATCH for database)
5. **n8n → Gmail** (MCP or API for notifications)

**Critical Integration Requirements**:
- All HTTP calls must have timeout (30s max)
- All external APIs must handle rate limits gracefully
- All integrations must log request/response for debugging
- No hardcoded credentials (environment variables only)

---

## Test Strategy

### Unit-Level Testing (Per Stage)

**Test Each Stage Independently**:
- Stage 1: Can it find 20 clinics in Austin, TX?
- Stage 2: Can it extract 20+ reviews for a known clinic?
- Stage 3: Can it find emails using all 3 methods?
- Stage 4: Does pain analysis produce valid JSON with evidence?
- Stage 5: Do lead scores make logical sense?
- Stage 6: Are emails personalized and professional?

**Success Criteria**: Each stage must work in isolation before integrating

### Integration Testing (End-to-End)

**Test Case 1: Perfect Scenario**
- Input: Miami, FL (high-density market)
- Expected: 20 clinics, 70%+ emails, 5+ A-tier leads
- Validates: Happy path works completely

**Test Case 2: Sparse Market**
- Input: Small town with only 8 PT clinics
- Expected: Finds all 8, doesn't crash, reports correctly
- Validates: Graceful handling of limited data

**Test Case 3: Scraping Blocked**
- Simulate: Website returns 403 or CAPTCHA
- Expected: Falls back to pattern generation, doesn't lose lead
- Validates: Error handling and fallbacks work

**Test Case 4: External Service Down**
- Simulate: Supabase unreachable
- Expected: Uses Google Sheets backup, sends alert
- Validates: Backup strategies and alerting work

**Test Case 5: No Reviews Found**
- Input: New clinic with 0 reviews
- Expected: Saves clinic, marks low confidence, no email generated
- Validates: Handles missing data gracefully

### Production Monitoring

**Daily Checks**:
- Did all 4 scheduled runs complete?
- Are error rates <5%?
- Is email enrichment rate ≥70%?
- Did any A-tier leads get missed?

**Weekly Analysis**:
- Response rate trends (improving or declining?)
- Which pain points are most common?
- Which cities have best lead quality?
- Are we getting blocked anywhere?

---

## Environment Variables Required

```bash
# Playwright Container
PLAYWRIGHT_CONTAINER_URL=http://playwright:3000

# Claude API
ANTHROPIC_API_KEY=sk-ant-xxx  # From console.anthropic.com

# Supabase
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=xxx  # Public key for client-side
SUPABASE_SERVICE_KEY=xxx  # Secret key for server-side operations

# Gmail Notifications
GMAIL_OAUTH_TOKEN=xxx  # From Google OAuth2 flow
NOTIFICATION_EMAIL=jason@corereceptionai.com

# Optional: Backup Storage
GOOGLE_SHEETS_ID=xxx  # Only if implementing backup
GOOGLE_SERVICE_ACCOUNT_JSON=xxx  # Service account credentials

# Webhook Security
WEBHOOK_SECRET=random-long-string-here  # For webhook path obfuscation

# Rate Limiting
MAX_CONCURRENT_SCRAPES=3  # Playwright parallel limit
CLAUDE_API_RPM_LIMIT=50  # Requests per minute limit
```

---

## Definition of Done

This workflow is **PRODUCTION READY** when:

✅ **Functional Requirements**:
- Discovers 20 clinics per run from Google Maps
- Extracts reviews and analyzes pain points
- Enriches contact data with 70%+ success rate
- Generates personalized emails for qualified leads
- Stores all data in Supabase
- Sends notifications for A-tier leads

✅ **Quality Requirements**:
- Zero data loss (backup strategies working)
- <5% error rate per run
- All errors logged and traceable
- Lead scores are logical and explainable
- Generated emails are professional and specific

✅ **Operational Requirements**:
- Runs on schedule 4x daily without intervention
- Completes 20-clinic batch in <30 minutes
- Handles errors gracefully without crashing
- Sends clear alerts for critical failures
- Respects rate limits (no IP bans)

✅ **Documentation Requirements**:
- Architecture document complete
- Test cases documented
- Environment variables listed
- Error scenarios documented
- Recovery procedures defined

✅ **Business Requirements**:
- Produces actionable A-tier leads daily
- Email quality warrants human approval before send
- Data quality supports 5-10% response rate target
- System cost <$300/month on free tiers

---

## What Success Looks Like

**Week 1**: System researches 100 clinics, generates 30 qualified leads
**Week 2**: Human sends first outreach emails, gets 5-10% response rate
**Week 3**: Books 2-3 discovery calls from email outreach
**Month 1**: Closes first deal from system-generated lead

**System Impact**:
- Research time: 60 hours manual → 1 hour automated per 100 clinics
- Response rate: 0.5% generic → 5-10% personalized
- Cost per lead: $50 manual → $2 automated
- Time to first meeting: Weeks → Days

**This is NOT just a scraper. It's an intelligence engine that positions you as a consultant who's done research, not a vendor sending spam.**

---

## Priority

**Critical** (blocks revenue generation)

## Timeline

- **Week 1**: Build and test
- **Week 2**: Deploy and monitor first real campaigns
- **Month 1**: Scale to 20+ cities

## Pipeline Metadata

- **Status**: pending
- **Current Stage**: 0 - awaiting Claude Code implementation
- **Created**: 2025-01-10
- **Owner**: CoreReceptionAI
- **Target Users**: PT clinic owners/managers
