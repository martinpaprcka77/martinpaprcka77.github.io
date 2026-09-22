# Pull Request

## Description
<!-- What does this PR change? -->

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactor / optimization
- [ ] Documentation
- [ ] Tests

## Checklist
- [ ] Tests added/updated in `toolkit/tests/`
- [ ] Full gate passes: `pwsh -File toolkit/build/Test.ps1` (manifest parity + Pester + PSScriptAnalyzer)
- [ ] Comment-based help on all new functions
- [ ] Idempotent where applicable
- [ ] Platform-guarded (`-not $IsWindows`) where Windows-only
- [ ] `docs/MANUAL.md` updated if user-facing change
- [ ] `AGENTS.md` / `CLAUDE.md` updated if architecture change

## Test output
```
Tests Passed: 65, Failed: 0
```

## Related issues
<!-- Closes #... -->
