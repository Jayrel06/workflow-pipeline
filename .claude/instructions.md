# Claude Code Instructions for Workflow Pipeline

## Memory System Integration

**IMPORTANT**: This project is connected to a PostgreSQL long-term memory system that stores:
- Code patterns and best practices
- Business knowledge
- Workflow templates and examples
- GitHub activity and learnings

### When to Query Memory System

**ALWAYS check the memory system BEFORE:**
1. Creating new n8n workflows (check for similar patterns)
2. Implementing complex logic (look for proven solutions)
3. Handling common use cases (reuse existing knowledge)
4. Making architectural decisions (learn from past implementations)

### Memory System API Endpoints

**Base URL**: `http://localhost:3001/api`

**Available Endpoints**:
```bash
# Search patterns
GET /patterns/search?q={query}&limit=10

# Get specific pattern
GET /patterns/{id}

# Search knowledge
GET /knowledge/search?q={query}&limit=10

# Get workflow templates
GET /prompts?category=workflow&limit=10

# Get recent GitHub activity
GET /github/activity?repo={repo}&limit=20

# Get stats
GET /stats
```

### Usage Examples

**Before creating a webhook workflow:**
```bash
curl http://localhost:3001/api/patterns/search?q=webhook&limit=5
```

**Before implementing authentication:**
```bash
curl http://localhost:3001/api/knowledge/search?q=authentication&limit=5
```

**Check for similar workflows:**
```bash
curl http://localhost:3001/api/prompts?category=workflow&limit=10
```

### Best Practices

1. **Query First**: Always search memory before implementing
2. **Learn from Patterns**: Reuse proven code patterns
3. **Document New Patterns**: After implementing something novel, document it
4. **Update Knowledge**: Add learnings to the system for future use

### Automatic Integration

The memory system automatically captures:
- ✅ All GitHub commits (patterns extracted)
- ✅ All pull requests (knowledge captured)
- ✅ All issues (tracked and analyzed)
- ✅ All releases (documented)

Your code contributions automatically become part of the knowledge base!

## Workflow Development Guidelines

### Stage 2: Claude Code Implementation

When you receive a workflow spec from Stage 1:

1. **Check Memory System** for similar workflows
2. **Review n8n node patterns** from past implementations
3. **Implement the workflow** following the spec
4. **Document any new patterns** discovered
5. **Output to**: `03-stage-2-claude-code/output/`

### Quality Standards

- Use memory system patterns for consistency
- Follow n8n best practices from knowledge base
- Implement error handling (check `/patterns/search?q=error+handling`)
- Add retry logic where appropriate (check `/patterns/search?q=retry`)
- Validate all inputs (check `/knowledge/search?q=validation`)

### Testing

Before submitting:
1. Validate JSON structure
2. Check credentials are properly referenced
3. Ensure all nodes are connected
4. Add workflow tags from memory system categories

## Getting Help

If stuck, query the memory system:
```bash
# General help
curl http://localhost:3001/api/knowledge/search?q=n8n+workflow+help

# Specific issues
curl http://localhost:3001/api/patterns/search?q=your+specific+issue
```

The memory system learns from every implementation - your work helps future projects!
