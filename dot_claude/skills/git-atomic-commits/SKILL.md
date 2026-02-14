---
name: git-atomic-commits
description: >
  Guide for creating atomic git commits that break changes into the smallest
  possible diffs. Use when committing code, planning commit strategies, reviewing
  commit granularity, or structuring changes for pull requests. Activates on
  keywords like atomic commit, small commits, commit strategy, breaking up
  commits, or commit granularity.
metadata:
  version: "1.0.0"
---

# Atomic Commits

An atomic commit is a commit in which code has been broken down into the smallest possible diff, minimizing the number of changes made.

## Benefits

1. **Easy isolation and revert**: If any code causes a breaking change, the offending commit is easy to isolate and revert to a working state. This ensures supported applications remain stable and resilient against newly introduced bugs.

2. **Easier code review**: The git history becomes a step-by-step guide for understanding changes. This helps developers who may lack context around changes or why they were done in a particular order.

3. **Fewer merge conflicts**: Changes are much less likely to conflict with other branches. Even if collisions occur, the resulting merge conflicts will be smaller and more manageable.

## Rules

- An atomic commit does NOT mean committing a single file at a time or a set number of lines. Distill each change into its own event, keeping it separate from other related changes.
- Each commit MUST be able to stand on its own as a complete, self-contained change.
- All relevant tests MUST be committed together with the code they apply to. Never separate test files from their implementation.

## Example: Implementing a New Rails Model

Break the work into distinct, self-contained commits:

### 1. Create the migration and model

```
Add User model

Files:
  new file:   db/migrate/202001010000_add_user_model.rb
  new file:   app/models/user.rb
```

### 2. Create relevant associations

```
Add relations between User and Organization

Files:
  modified:   app/models/user.rb
  modified:   app/models/organization.rb
```

### 3. Write a scoped query (with tests)

```
Add User#active_users scope

Files:
  modified:   app/models/user.rb
  new file:   spec/models/user_spec.rb
```

### 4. Create controller and view

```
Add UsersController with index action

Files:
  new file:   app/controllers/users_controller.rb
  new file:   app/views/users/index.html.erb
```

### 5. Update existing views to link to new pages

```
Add link to UsersController#index on OrganizationsController#show page

Files:
  modified:   app/controllers/organizations_controller.rb
  modified:   app/views/organizations/show.html.erb
```

## Further Reading

- [Wikipedia: Atomic Commit](https://en.wikipedia.org/wiki/Atomic_commit)
- [Fresh Consulting: Atomic Commits](https://www.freshconsulting.com/atomic-commits/)
