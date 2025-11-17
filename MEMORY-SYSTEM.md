# Memory System Integration

## Overview

This workflow pipeline is connected to a **PostgreSQL long-term memory system** that automatically captures and organizes:
- Code patterns and implementations
- Business knowledge and best practices
- Workflow templates and examples
- GitHub activity (commits, PRs, issues, releases)
- AI-generated insights and recommendations

## How It Works

### Automatic Data Collection

Every action in your GitHub repos triggers the memory system:

```
GitHub Event → n8n Webhook → Memory System
     ↓              ↓              ↓
  [Push]    → Pattern Extract → Database
  [PR]      → Knowledge Capture → Database
  [Issue]   → Problem Tracking → Database
  [Release] → Documentation → Database
```

### Connected Repositories

All webhooks configured for:
- **pt-ops-whisperer**
- **workflow-pipeline** (this repo)
- **corereceptionai**
- **skills-introduction-to-github**

## Using the Memory System

### API Access

**Base URL**: `http://localhost:3001/api`

### Common Queries

**Find workflow patterns:**
```bash
curl http://localhost:3001/api/patterns/search?q=webhook&language=javascript
```

**Search knowledge base:**
```bash
curl http://localhost:3001/api/knowledge/search?q=authentication
```

**Get workflow templates:**
```bash
curl http://localhost:3001/api/prompts?category=workflow
```

**Check recent activity:**
```bash
curl http://localhost:3001/api/github/activity?repo=workflow-pipeline
```

**Get system stats:**
```bash
curl http://localhost:3001/api/stats
```

## n8n Workflows Running

The memory system includes 20 automated workflows:

### Core Memory Operations
- **Memory Sync**: Syncs data every 6 hours
- **Pattern Extraction**: Extracts code patterns from commits
- **Knowledge Aggregation**: Combines insights from multiple sources
- **Prompt Optimizer**: Optimizes AI prompts based on usage

### AI-Powered Features
- **Insight Generator**: Generates insights from collected data
- **Codex Auto Review**: Automatic code reviews via AI
- **Knowledge Recommendation**: Suggests relevant knowledge
- **Pattern Suggestion**: Recommends patterns for new code

### Integrations
- **GitHub to Memory**: Captures all GitHub events → Memory
- **API Health Monitoring**: Monitors memory system health
- **Email Pattern Digest**: Weekly digest (Fridays 9 AM)
- **Slack Knowledge Bot**: Query memory via Slack `/memory` command

### PT Clinic Workflows
- **Lead Enrichment**: Enriches leads with context
- **Client Knowledge Capture**: Captures client interactions
- **Compliance Tracker**: Tracks compliance requirements
- **PT Workflow Optimizer**: Optimizes PT clinic workflows

### Utilities
- **System Health Check**: Monitors all systems
- **Backup Memory System**: Daily backups
- **Cleanup Old Data**: Monthly data cleanup
- **Generate Analytics Reports**: Weekly analytics

## For Claude Code

When implementing workflows:

1. **Query First**: Check if similar pattern exists
   ```bash
   curl http://localhost:3001/api/patterns/search?q=your+use+case
   ```

2. **Learn from History**: Review past implementations
   ```bash
   curl http://localhost:3001/api/github/activity?limit=50
   ```

3. **Reuse Patterns**: Don't reinvent the wheel
   ```bash
   curl http://localhost:3001/api/prompts?category=workflow
   ```

4. **Contribute Back**: Your implementations automatically become knowledge

## System Status

**Access Points:**
- **n8n**: https://workflows.n8nlocalhost5678.win
- **Memory API**: http://localhost:3001
- **API Health**: http://localhost:3001/health

**Current Stats:**
```bash
curl http://localhost:3001/api/stats
```

## Benefits

✅ **Never start from scratch** - Reuse proven patterns
✅ **Learn from mistakes** - Past issues documented
✅ **Consistent quality** - Validated approaches
✅ **Faster development** - Templates and examples ready
✅ **Knowledge accumulation** - Every project adds value
✅ **AI-powered insights** - Automatic recommendations

## Integration in Pipeline

```
00-input → You describe workflow
    ↓
01-stage-1 → Claude Desktop checks memory for patterns
    ↓
02-gate-1 → Validates against known patterns
    ↓
03-stage-2 → Claude Code queries memory for implementation
    ↓
04-gate-2 → Compares to security patterns
    ↓
05-stage-3 → Codex optimizes using learned patterns
    ↓
[New workflow added to memory automatically via GitHub webhook]
```

Every workflow you create improves the system for the next one!
