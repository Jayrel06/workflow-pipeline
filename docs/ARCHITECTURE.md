# Workflow Pipeline Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        USER INPUT                            │
│            (Workflow Description in Markdown)                │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           STAGE 1: Claude Desktop (Architecture)            │
│  • Generate n8n workflow architecture                        │
│  • Create implementation guide                               │
│  • Define test specifications                                │
│  MCPs: Context7 (docs), n8n MCP (templates)                 │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           GATE 1: Spec Validation                            │
│  • Validate completeness                                     │
│  • Check tech stack compatibility                           │
│  • Verify all requirements covered                           │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           STAGE 2: Claude Code (Implementation)              │
│  • Generate n8n workflow JSON                                │
│  • Create test payloads                                      │
│  • Document implementation notes                             │
│  MCPs: n8n MCP (validation), Context7 (verification)        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           GATE 2: Structure & Security                       │
│  • Validate JSON structure                                   │
│  • Security scan (credentials, webhooks)                     │
│  • Check error handling                                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│    STAGE 3: Codex (Automatic GitHub PR Review) ← YOU ARE HERE │
│  • Automatic PR reviews via GitHub Actions                   │
│  • Security scanning (AGENTS.md guidelines)                  │
│  • Merge protection on P0 issues                             │
│  MCPs: n8n MCP, GitHub MCP, Context7 MCP                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           GATE 3: Quality & Performance                      │
│  • Performance testing                                       │
│  • Code quality checks                                       │
│  • Optimization validation                                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           STAGE 4: Final Human Review (Optional)             │
│  • Manual review if needed                                   │
│  • Approval for production                                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           GATE 4: Integration Test                           │
│  • End-to-end testing                                        │
│  • Integration validation                                    │
│  • Production readiness check                                │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  PRODUCTION DEPLOYMENT                       │
│              ✅ READY FOR n8n IMPORT                         │
└─────────────────────────────────────────────────────────────┘
```

## MCP Integration Architecture

```
                    ┌──────────────────────┐
                    │   Claude Code/Codex  │
                    │  (Orchestration)     │
                    └──────────┬───────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼────────┐   ┌────────▼───────┐   ┌─────────▼────────┐
│  Playwright    │   │   GitHub MCP   │   │  Docker Hub MCP  │
│   (Browser     │   │  (Version Ctl) │   │  (Containers)    │
│   Automation)  │   │                │   │                  │
│ • UI Testing   │   │ • Create PRs   │   │ • Validate       │
│ • Import Tests │   │ • Commit Files │   │ • Check Updates  │
│ • Screenshots  │   │ • Manage Issues│   │ • Monitor Health │
└───────┬────────┘   └────────┬───────┘   └─────────┬────────┘
        │                     │                      │
        │                     │                      │
┌───────▼────────┐   ┌────────▼───────┐   ┌─────────▼────────┐
│  Grafana MCP   │   │ Prometheus MCP │   │  Postgres MCP    │
│  (Dashboards)  │   │  (Metrics)     │   │  (Database)      │
│                │   │                │   │                  │
│ • Create Dash  │   │ • Collect Data │   │ • Test Queries   │
│ • Visualize    │   │ • Alert Rules  │   │ • Validate Data  │
└───────┬────────┘   └────────┬───────┘   └─────────┬────────┘
        │                     │                      │
        └─────────────────────┼──────────────────────┘
                              │
                     ┌────────▼────────┐
                     │   Memory MCP    │
                     │   (Learning)    │
                     │ • Store Patterns│
                     │ • Recall Success│
                     └─────────────────┘
```

## Data Flow

```
User Request
    ↓
[Stage 1: Architecture Document]
    ↓
[Stage 2: n8n Workflow JSON]
    ↓
[Push to GitHub]
    ↓
[GitHub Actions Triggered]
    ↓
[Codex Review]
    ↓
[Fix Issues] → [Re-review]
    ↓
[Merge to Main]
    ↓
[Deploy to n8n]
```

## Technology Stack

- **AI Models**: Claude Desktop, Claude Code, Codex
- **Workflow Engine**: n8n
- **Version Control**: GitHub
- **Automation**: GitHub Actions
- **MCPs (7 active)**: Playwright, GitHub, Docker Hub, Grafana, Postgres, Prometheus, Memory
- **Infrastructure (11 containers)**: n8n, postgres, grafana, prometheus, playwright, redis, python-ai, jupyter, mailserver, portainer, cloudflared
- **Monitoring**: Grafana, Prometheus
- **Testing**: Playwright, Postgres test database
- **Solo Developer Focus**: No team tools (Slack removed)

## Key Innovations

1. **Multi-AI Validation**: Different AIs catch different types of bugs
2. **MCP Integration**: 6 servers provide comprehensive validation
3. **Automatic Reviews**: Zero manual intervention required
4. **Merge Protection**: Critical issues block deployment
5. **Continuous Improvement**: Metrics-driven optimization

---

*Architecture Documentation - Version 1.0*
