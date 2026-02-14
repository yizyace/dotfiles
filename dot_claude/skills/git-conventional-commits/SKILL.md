---
name: conventional-commits
description: >
  Format git commit messages following the Conventional Commits 1.0.0 specification.
  Use when writing commit messages, generating changelogs, or determining semantic
  version bumps. Applies to any git workflow where structured, machine-readable commit
  messages are needed. Activates on keywords like commit, commit message, conventional
  commit, changelog, or semantic versioning.
license: CC-BY-3.0
metadata:
  author: conventional-commits
  version: "1.0.0"
  source: https://www.conventionalcommits.org/en/v1.0.0/
---

# Conventional Commits

A specification for adding human and machine readable meaning to commit messages.

## Commit Message Structure

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Structural Elements

1. **`fix`**: Patches a bug (correlates with `PATCH` in SemVer).
2. **`feat`**: Introduces a new feature (correlates with `MINOR` in SemVer).
3. **`BREAKING CHANGE`**: A footer `BREAKING CHANGE:`, or a `!` after the type/scope, introduces a breaking API change (correlates with `MAJOR` in SemVer). Can be part of any commit type.
4. **Other types**: `build:`, `chore:`, `ci:`, `docs:`, `style:`, `refactor:`, `perf:`, `test:`, and others are allowed.
5. **Footers** other than `BREAKING CHANGE: <description>` follow a convention similar to git trailer format.

## Specification Rules

1. Commits MUST be prefixed with a type (`feat`, `fix`, etc.), followed by an OPTIONAL scope, OPTIONAL `!`, and REQUIRED terminal colon and space.
2. The type `feat` MUST be used when a commit adds a new feature.
3. The type `fix` MUST be used when a commit represents a bug fix.
4. A scope MAY be provided after a type. A scope MUST consist of a noun describing a section of the codebase surrounded by parentheses, e.g., `fix(parser):`.
5. A description MUST immediately follow the colon and space after the type/scope prefix. It is a short summary of the code changes.
6. A longer commit body MAY be provided after the short description. The body MUST begin one blank line after the description.
7. A commit body is free-form and MAY consist of any number of newline-separated paragraphs.
8. One or more footers MAY be provided one blank line after the body. Each footer MUST consist of a word token, followed by either a `:<space>` or `<space>#` separator, followed by a string value.
9. A footer's token MUST use `-` in place of whitespace characters, e.g., `Acked-by`. Exception: `BREAKING CHANGE` MAY also be used as a token.
10. A footer's value MAY contain spaces and newlines. Parsing MUST terminate when the next valid footer token/separator pair is observed.
11. Breaking changes MUST be indicated in the type/scope prefix of a commit, or as an entry in the footer.
12. If included as a footer, a breaking change MUST consist of the uppercase text `BREAKING CHANGE`, followed by a colon, space, and description.
13. If included in the type/scope prefix, breaking changes MUST be indicated by a `!` immediately before the `:`. If `!` is used, `BREAKING CHANGE:` MAY be omitted from the footer section, and the commit description SHALL describe the breaking change.
14. Types other than `feat` and `fix` MAY be used in commit messages, e.g., `docs: update ref docs`.
15. The units of information that make up Conventional Commits MUST NOT be treated as case sensitive by implementors, with the exception of `BREAKING CHANGE` which MUST be uppercase.
16. `BREAKING-CHANGE` MUST be synonymous with `BREAKING CHANGE` when used as a token in a footer.

## Examples

### Commit with description and breaking change footer

```
feat: allow provided config object to extend other configs

BREAKING CHANGE: `extends` key in config file is now used for extending other config files
```

### Commit with `!` to draw attention to breaking change

```
feat!: send an email to the customer when a product is shipped
```

### Commit with scope and `!`

```
feat(api)!: send an email to the customer when a product is shipped
```

### Commit with both `!` and BREAKING CHANGE footer

```
chore!: drop support for Node 6

BREAKING CHANGE: use JavaScript features not available in Node 6.
```

### Commit with no body

```
docs: correct spelling of CHANGELOG
```

### Commit with scope

```
feat(lang): add Polish language
```

### Commit with multi-paragraph body and multiple footers

```
fix: prevent racing of requests

Introduce a request id and a reference to latest request. Dismiss
incoming responses other than from latest request.

Remove timeouts which were used to mitigate the racing issue but are
obsolete now.

Reviewed-by: Z
Refs: #123
```

### Revert commit

```
revert: let us never again speak of the noodle incident

Refs: 676104e, a215868
```

## SemVer Mapping

| Commit type | SemVer bump |
|---|---|
| `fix` | `PATCH` |
| `feat` | `MINOR` |
| Any type with `BREAKING CHANGE` | `MAJOR` |
