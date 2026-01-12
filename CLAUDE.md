# CLAUDE.md - Development Guidelines for reminder-cli

This document contains development conventions and guidelines for the reminder-cli project when working with Claude Code.

## Version Management and Release Process

### Release Candidate (RC) Workflow

When implementing new features or making changes:

1. **Start with RC version**
   - Increment the patch version and add `-rc1` suffix
   - Example: If current version is `0.1.1`, start with `0.1.2-rc1`
   - Update version in:
     - `Sources/reminder-cli/reminder_cli.swift` (CommandConfiguration version)
     - Any other version references

2. **During development and testing**
   - Keep the `-rc1` suffix while testing
   - If further changes are needed, increment RC number: `-rc2`, `-rc3`, etc.
   - Build and test thoroughly with the RC version

3. **After confirming everything works**
   - Remove the RC suffix (e.g., `0.1.2-rc1` → `0.1.2`)
   - Update version in all relevant files
   - Create a git commit with the changes
   - Create and push a git tag for the release

### Example Workflow

```bash
# 1. Update version to RC in source files
# Set version to "0.1.2-rc1" in reminder_cli.swift

# 2. Build and test
make build
make test  # or manual testing

# 3. If everything works, remove RC suffix
# Change version to "0.1.2" in reminder_cli.swift

# 4. Commit and tag
git add .
git commit -m "Release v0.1.2: Add output format options (json, yaml, pretty-json)"
git tag v0.1.2
git push origin main
git push origin v0.1.2
```

## Project Structure

- `Sources/reminder-cli/reminder_cli.swift` - CLI command structure and argument parsing
- `Sources/reminder-cli/ReminderStore.swift` - EventKit business logic
- `Sources/reminder-cli/OutputFormatter.swift` - Output format handling (text, json, yaml)
- `Package.swift` - Swift package configuration
- `Makefile` - Build automation

## EventKit API Limitations

The following features are NOT available through Apple's EventKit framework:

- **Flags** - The "flagged" indicator is not accessible via EventKit
- **Tags** - Introduced in iOS 15, but not exposed in EventKit API
- **Attachments** - Not accessible on EKReminder objects

These limitations have been thoroughly investigated and confirmed through:
- Compilation tests
- Objective-C selector checks
- Official Apple documentation review

See README.md for more details on EventKit limitations.

## Code Style

- Use Swift 5 language mode (set in Package.swift) to avoid EventKit concurrency issues
- Follow existing code patterns for consistency
- Keep error handling informative and user-friendly
- Use emoji sparingly in output (only where it adds clarity)

## Testing

Before creating a release:

1. Test all CRUD operations (List, Show, Create, Update, Delete, Complete)
2. Test all output formats (text, json, pretty-json, yaml)
3. Verify the CLI works with `make run`
4. Check that `make install` installs to `~/bin` correctly
5. Test with real iCloud Reminders data

## Commit Message Format

Use descriptive commit messages that explain what changed and why:

```
Add feature: Brief description of the feature

- Detail 1
- Detail 2

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

For releases:
```
Release v0.1.2: Brief summary of main changes

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```
