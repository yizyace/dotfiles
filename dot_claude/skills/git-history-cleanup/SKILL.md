---
name: git-history-cleanup
description: >
  Guide for cleaning up git history using interactive rebasing, fixup commits,
  and autosquashing. Use when rebasing branches, resolving merge conflicts during
  rebase, creating fixup commits for code review feedback, squashing commits, or
  cleaning up commit history before merging. Activates on keywords like rebase,
  fixup, autosquash, squash commits, clean history, or interactive rebase.
metadata:
  version: "1.0.0"
---

# Rebasing, Fixup Commits, and Autosquashing

## Rebasing

Rebasing takes a git branch from its original branch point and replays its commits on top of a different commit. Depending on what files changed, there may or may not be conflicts requiring manual resolution.

### Graphical Example

Before rebase:
```
* bbfe18e (rebase-branch) Even more branch commits
* e83a812 Branch commit for README
| * 3a1ec67 (HEAD -> master) Another merge from another branch
| * f53c9c0 Commits from a different branch
|/
* eb4af0b Flesh out README
* 1a9a0b0 Initial commit
```

After rebase:
```
 * bbfe18e (rebase-branch) Even more branch commits
 * e83a812 Branch commit for README
/
* 3a1ec67 (HEAD -> master) Another merge from another branch
* f53c9c0 Commits from a different branch
* eb4af0b Flesh out README
* 1a9a0b0 Initial commit
```

### Steps to Perform a Rebase

1. **Fetch latest commits**:
   ```
   git fetch
   ```

2. **Run interactive rebase** (replace `origin/master` with the target branch):
   ```
   git rebase -i origin/master
   ```
   This opens an editor showing commits staged for rebase:
   ```
   pick e83a812 Branch commit for README
   pick bbfe18e Even more branch commits
   ```
   Write and quit to proceed.

3. **Resolve conflicts** (if any). When a conflict occurs, git will display an error. Run `git status` to see files marked `both modified`. Edit each conflicting file, resolve the merge markers (`<<<<<<<`, `=======`, `>>>>>>>`), then:
   ```
   git add <resolved-file>
   git rebase --continue
   ```

4. **Force push** the rebased branch:
   ```
   git push origin --force-with-lease
   ```
   Use `--force-with-lease` (never bare `--force`) to avoid overwriting others' work.

### Aborting a Rebase

Run `git rebase --abort` at any point during conflict resolution to return to the pre-rebase state.

### Rebasing Onto a Rebased Branch

When rebasing a branch-of-a-branch where the base was itself rebased, duplicate commits may appear. Change `pick` to `drop` for any duplicate commits:
```
drop e83a812 Branch commit for README       # Duplicate
drop bbfe18e Even more branch commits       # Duplicate
pick 2f1bf5b Additional changes
```

## Fixup Commits and Autosquashing

Use fixup commits to address code review feedback without disturbing existing atomic commits or redoing the commit history.

### Creating a Fixup Commit

1. Stage the changes as usual:
   ```
   git add -p
   ```

2. Find the commit hash to fixup onto:
   ```
   git log
   ```

3. Create the fixup commit:
   ```
   git commit --fixup <COMMIT_HASH>
   ```
   This creates a commit prefixed with `fixup!` that references the target commit message. This can be done any number of times, for any number of commits, in any order.

### Cleaning Up With Autosquash

Once all fixup commits are in place, rebase with `--autosquash` to fold them into the correct commits automatically:

```
git rebase -i --autosquash origin/master
```

The editor will show fixup commits automatically ordered below their target:
```
pick e83a812 Branch commit for README
fixup 2b0b37e fixup! Branch commit for README
fixup 31f00a2 fixup! Branch commit for README
pick bbfe18e Even more branch commits
fixup 9a6b90e fixup! Even more branch commits
```

Write and quit to complete. The fixup commits are folded into their target commits, and the history is clean and ready to push.

## Further Reading

- [The Git Fixup Workflow (Panter)](https://blog.panter.ch/2018/09/18/the-git-fixup-workflow.html)
