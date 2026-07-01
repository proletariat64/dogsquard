# Dogsquard PR Review Output Contract

Return exactly one Dogsquard review comment in this shape:

```markdown
## 🤖 Dogsquard AI Code Review

<!-- dogsquard-ai-code-review -->

### Verdict
PASS / NEEDS_ATTENTION / HIGH_RISK / SKIP

### What changed
- ...

### Must fix
- None.

### Should consider
- None.

### Test gaps
- None.

### Acceptance check
- ...

### File-skip check
- Skip used: yes/no.
- Reason: ...

### Dogsquard boundary check
- ...

### Engine details
- Engine: claude-deepseek / qoder
- Model: known value or unknown
```

Verdict rules:

- `PASS`: no concrete issue found.
- `NEEDS_ATTENTION`: non-blocking concerns or gaps worth human attention.
- `HIGH_RISK`: concrete correctness, security, CI, or Dogsquard template-boundary risk found.
- `SKIP`: provider invocation skipped because all changed files are safe binary/document assets.

All verdicts are advisory by model judgment. They do not replace `PR Quality Gate`.
