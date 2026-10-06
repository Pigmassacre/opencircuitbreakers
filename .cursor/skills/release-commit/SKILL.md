---
name: release-commit
description: Make a release commit for OpenCircuitBreakers that bumps the version in project.godot and export_presets.cfg and adds the release's changes to CHANGELOG.md. Use when the user asks for a release commit, a version bump, a new release, or to update the changelog.
disable-model-invocation: true
---

# Release commit

## Version files

All three must agree, or `Tools/release.sh` refuses to package:

| File | Key | Format |
|------|-----|--------|
| `Project/project.godot` | `config/version` | `"1.2.3"` |
| `Project/export_presets.cfg` | `application/file_version` | `"1.2.3.0"` |
| `Project/export_presets.cfg` | `application/product_version` | `"1.2.3.0"` |

## Workflow

1. **Pick the new version.** Use the version the user gave. Otherwise bump the patch number (`1.0.2` to `1.0.3`). Bump minor only when the user asks for it.
2. **Find the previous release.** Every release commit is tagged `v<version>`. Fetch the tags first, since a clone may not have them:
   ```bash
   git fetch --tags origin
   git describe --tags --abbrev=0
   ```
3. **Collect the changes.** Read every commit after that tag:
   ```bash
   git log --reverse --format='%h %s%n%b' <previous>..HEAD
   ```
   Open a diff with `git show <hash>` when a subject is too vague to describe for players.
4. **Write the changelog entry** (format below). Create `CHANGELOG.md` at the repo root if it does not exist. Put the new version above older entries.
5. **Bump the three version fields.**
6. **Commit** only `CHANGELOG.md`, `Project/project.godot` and `Project/export_presets.cfg`, with the message `Release <version>`. Leave other working-tree changes out.
7. **Tag the release commit**:
   ```bash
   git tag -a v<version> -m "Release <version>"
   ```
8. **Push** only when the user asks. The user may have amended the release commit since it was tagged, so first check that the tag still points at it, and re-tag if it does not:
   ```bash
   git rev-parse "v<version>^{commit}" HEAD
   git tag -f -a v<version> -m "Release <version>" HEAD
   ```
   Then push the tag with the branch:
   ```bash
   git push origin HEAD v<version>
   ```
   If a stale tag is already on the remote, move it with `git push -f origin v<version>`, but only while no GitHub release uses it.
   Never run `Tools/release.sh publish` unless the user asks, because it uploads a public GitHub release. It refuses to run until `v<version>` is on the remote, and it uses this version's `CHANGELOG.md` section as the release notes.

## Changelog format

```markdown
# Changelog

## 1.0.3 - 2026-10-06

### Added
- Bumper Cars mode in the main menu, next to Battle and Time Trial.

### Changed
- ...

### Fixed
- Bumper cars show each player's colour and number plate.
```

- Use today's date, `YYYY-MM-DD`.
- Use only the headings that have entries, in the order Added, Changed, Fixed.
- Write for players: describe what changed in the game, not function names, RE addresses or file paths.
- Merge related commits into one entry. Leave out commits that players cannot notice, such as `FINDINGS.md`, `TODO.md`, refactors and tooling.
