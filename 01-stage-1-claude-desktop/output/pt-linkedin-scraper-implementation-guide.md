# PT LinkedIn Scraper - Implementation (Streamlined)

## Workflow Structure
Manual Trigger → Branch by Mode → [Pain Discovery OR Profile Enrichment] → Rate Limit Check → Store → Report

## Key Configurations
- **Pain Discovery**: Search LinkedIn posts, filter owner titles, categorize with Claude
- **Profile Enrichment**: Search "{clinic name} owner", extract first result, store
- **Rate Limiting**: Track operations in workflow state, alert at 140/150

## Critical Nodes
1. Manual Trigger: Mode selection
2. Kapture nodes: Login (pause), search, extract
3. Claude API: Categorize pain points
4. Postgres: INSERT into pain_points or decision_makers
5. Operation counter: Increment & check limit

## Environment Variables
```bash
CLAUDE_API_KEY=sk-ant-...
POSTGRES_CONNECTION_STRING=postgresql://...
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
```
