# Contributing

## Conventional Commits

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automatic release versioning via [release-please](https://github.com/google-github-actions/release-please-action).

Commit messages must follow this format:

```
<type>: <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Release impact | When to use |
|---|---|---|
| `feat` | minor bump | New feature (user-facing) |
| `fix` | patch bump | Bug fix |
| `docs` | — | Documentation changes only |
| `chore` | — | Build, CI, tooling, refactoring |
| `refactor` | — | Code restructuring with no behavior change |
| `test` | — | Adding or fixing tests |
| `style` | — | Formatting, whitespace (not CSS) |
| `perf` | patch bump | Performance improvement |
| `ci` | — | CI configuration changes |

### Breaking changes

Append `!` after the type or add `BREAKING CHANGE:` in the footer:

```
feat!: rename ASK_MODEL to ASK_AI_MODEL
```

```
feat: add dark theme support

BREAKING CHANGE: ASK_THEME env var renamed to ASK_AI_THEME
```

### Examples

```
feat: add ASK_AI_THEME env var for dark/light theme override
fix: wrap setFamilies() in try/except for Qt < 5.13
docs: add env var table to README
chore: rename ask-dolphin scripts to ask-ai-dolphin
ci: add Qt setFamilies() compatibility test
refactor: extract locale detection into dedicated function
test: add ASK_AI_THEME style selection tests
```

### Why

- `feat` → minor version bump (e.g., `1.0.0` → `1.1.0`)
- `fix` → patch version bump (e.g., `1.0.0` → `1.0.1`)
- `BREAKING CHANGE` → major version bump (e.g., `1.0.0` → `2.0.0`)
- `chore`, `docs`, `refactor`, `test`, `ci`, `style` → no release

## Pull Requests

1. Keep PRs focused on a single change
2. Use the conventional commit format for the PR title
3. Squash-merge PRs to ensure a clean commit history for release-please
4. CI must pass before merging
