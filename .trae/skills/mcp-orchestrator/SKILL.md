---
name: "mcp-orchestrator"
description: "Intelligently orchestrates MCP tools (Memory, Sequential Thinking, Chrome DevTools, DevEco, fetch, jina ai, duckduckgo, GitHub) based on task requirements. Invoke when user needs multi-step reasoning, web research, browser automation, knowledge management, or GitHub operations."
---

# MCP Orchestrator

This skill guides the intelligent selection and sequencing of MCP tools based on task requirements.

## Available MCP Tools

### 1. Memory (mcp_Memory_*)
**Purpose**: Knowledge graph management for persistent information storage
**Tools**: create_entities, create_relations, add_observations, delete_entities, delete_observations, delete_relations, read_graph, search_nodes, open_nodes

**When to use**:
- Storing project context, requirements, or decisions
- Building relationships between code components
- Maintaining long-term knowledge across conversations
- Tracking bugs, features, or architectural decisions

**Example**:
```
User: "Remember that we decided to use MVVM pattern"
→ Use mcp_Memory_create_entities to store this decision
```

### 2. Sequential Thinking (mcp_Sequential_Thinking_sequentialthinking)
**Purpose**: Multi-step reasoning and problem-solving

**When to use**:
- Complex problem breakdown
- Debugging with step-by-step analysis
- Design decisions requiring trade-off evaluation
- Tasks with unclear scope that need exploration

**Example**:
```
User: "How should I architect this feature?"
→ Use Sequential Thinking to explore options
```

### 3. Chrome DevTools MCP (mcp_Chrome_DevTools_MCP_*)
**Purpose**: Browser automation and web page interaction
**Tools**: navigate_page, click, fill, take_screenshot, evaluate_script, performance_start_trace, etc.

**When to use**:
- Testing web applications
- Automating browser interactions
- Performance analysis
- Taking screenshots for documentation
- Debugging UI issues

**Example**:
```
User: "Test the login flow on my web app"
→ Use Chrome DevTools MCP to automate the flow
```

### 4. DevEco MCP
**Purpose**: HarmonyOS/DevEco Studio integration

**When to use**:
- HarmonyOS-specific development tasks
- DevEco Studio operations
- ArkTS/ArkUI debugging

**Example**:
```
User: "Debug my HarmonyOS app"
→ Use DevEco MCP for HarmonyOS-specific debugging
```

### 5. Fetch (WebFetch, WebSearch)
**Purpose**: Web content retrieval and search

**When to use**:
- Retrieving documentation
- Researching APIs or libraries
- Getting latest information
- Fact-checking

**Example**:
```
User: "What's the latest version of React?"
→ Use WebSearch to find current version
```

### 6. Jina AI
**Purpose**: AI-powered content processing

**When to use**:
- Summarizing web content
- Extracting information from URLs
- Processing documents

**Example**:
```
User: "Summarize this article: https://..."
→ Use Jina AI to extract and summarize content
```

### 7. DuckDuckGo
**Purpose**: Privacy-focused web search

**When to use**:
- General web searches
- Finding code examples
- Research without tracking

**Example**:
```
User: "Find examples of HarmonyOS Navigation pattern"
→ Use DuckDuckGo to search for examples
```

### 8. GitHub
**Purpose**: GitHub repository operations

**When to use**:
- Repository management
- Issue/PR operations
- Code search on GitHub
- Release management

**Example**:
```
User: "Search for similar implementations on GitHub"
→ Use GitHub MCP to search repositories
```

## Decision Matrix

| Task Type | Primary MCP | Secondary MCP | Notes |
|-----------|-------------|---------------|-------|
| Complex reasoning | Sequential Thinking | Memory | Store reasoning steps |
| Web research | WebSearch/DuckDuckGo | Jina AI | Fetch details after search |
| Browser testing | Chrome DevTools | - | For UI automation |
| Knowledge management | Memory | - | Store and retrieve facts |
| HarmonyOS dev | DevEco | Memory | Store HarmonyOS patterns |
| Git operations | GitHub | - | Repo management |
| Documentation | Jina AI | Memory | Summarize and store |

## Best Practices

1. **Always check Memory first**: Before starting a task, search the knowledge graph for existing context
2. **Use Sequential Thinking for complex tasks**: Break down multi-step problems
3. **Chain MCPs logically**: Search → Fetch → Memory (store findings)
4. **Store important findings**: Use Memory to persist useful information
5. **Don't overuse browser automation**: Use Chrome DevTools only when necessary

## Usage Patterns

### Pattern 1: Research and Store
```
1. WebSearch for information
2. WebFetch to get detailed content
3. Memory.create_entities to store findings
```

### Pattern 2: Debug with Reasoning
```
1. Sequential Thinking to analyze problem
2. Chrome DevTools if UI-related
3. Memory to store solution
```

### Pattern 3: Complex Task Planning
```
1. Sequential Thinking to plan approach
2. Execute steps using appropriate MCPs
3. Memory to track progress
```

## Anti-Patterns to Avoid

- ❌ Using Chrome DevTools when a simple WebFetch would suffice
- ❌ Not checking Memory before starting similar tasks
- ❌ Using Sequential Thinking for simple, straightforward tasks
- ❌ Fetching the same URL multiple times without caching in Memory
- ❌ Using web search when local knowledge (Memory) already has the answer
