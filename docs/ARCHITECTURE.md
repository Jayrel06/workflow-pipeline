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
│   n8n MCP      │   │  Context7 MCP  │   │   GitHub MCP     │
│  (Primary)     │   │  (Documentation│   │  (Automation)    │
│                │   │   Validation)  │   │                  │
│ • Validate     │   │                │   │ • Create Files   │
│ • Create       │   │ • Get Docs     │   │ • Create PRs     │
│ • Execute      │   │ • Verify       │   │ • Manage Issues  │
└───────┬────────┘   └────────┬───────┘   └─────────┬────────┘
        │                     │                      │
        │                     │                      │
┌───────▼────────┐   ┌────────▼───────┐   ┌─────────▼────────┐
│  Brave Search  │   │  Kapture MCP   │   │ Resource Manager │
│  (Research)    │   │  (Browser)     │   │  (Cross-MCP)     │
│                │   │                │   │                  │
│ • Web Search   │   │ • Screenshots  │   │ • List Resources │
│ • Trends       │   │ • UI Testing   │   │ • Read Resources │
└────────────────┘   └────────────────┘   └──────────────────┘
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
- **MCPs**: n8n, Context7, GitHub, Brave Search, Kapture, Resources
- **Monitoring**: Grafana (optional), Prometheus (optional)
- **Testing**: Playwright, Custom validators

## Key Innovations

1. **Multi-AI Validation**: Different AIs catch different types of bugs
2. **MCP Integration**: 6 servers provide comprehensive validation
3. **Automatic Reviews**: Zero manual intervention required
4. **Merge Protection**: Critical issues block deployment
5. **Continuous Improvement**: Metrics-driven optimization

---

*Architecture Documentation - Version 1.0*
