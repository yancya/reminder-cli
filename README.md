# reminder-cli

A Swift-based command-line tool to manage iCloud Reminders on macOS.

## Features

- 📋 **List** - View all reminders or filter by specific list
- 🔍 **Show** - Display detailed information about a reminder (including alarms)
- ➕ **Create** - Add new reminders with notes, URLs, start/due dates, and priority
- ✏️ **Update** - Modify existing reminders
- 🗑️ **Delete** - Remove reminders (with confirmation prompt)
- ✅ **Complete** - Mark reminders as done
- 📍 **Location Alarms** - View location-based alarm details
- 🔗 **URL Support** - Associate URLs with reminders

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later (swift-tools-version 5.9)
- Xcode (for building)

## Installation

### Using Homebrew (Recommended)

```bash
brew install yancya/reminder-cli/reminder-cli
```

### From Source

```bash
git clone https://github.com/yancya/reminder-cli.git
cd reminder-cli
make install
```

This will build the release version and install it to `~/bin/reminder-cli`.

## Usage

### List reminders

```bash
# List all reminders from all lists
reminder-cli list

# List reminders from a specific list
reminder-cli list "Shopping"

# Include completed reminders
reminder-cli list --completed

# Sort order (due-date, priority, title, created, status)
reminder-cli list --sort priority

# Output format (text, json, pretty-json, yaml)
reminder-cli list --format pretty-json
```

List output includes a short ID prefix like `[29CC6D52]` that you can use for show/update/complete/delete. If the prefix is ambiguous, use a longer prefix or the full ID.

### Show reminder details

```bash
# By short ID prefix (from list output)
reminder-cli show 29CC6D52

# By full ID
reminder-cli show 29CC6D52-D95F-43D1-BF77-0777374C8D93

# Output format (text, json, pretty-json, yaml)
reminder-cli show 29CC6D52 --format yaml
```

### Create a new reminder

```bash
# Simple reminder
reminder-cli create "Buy milk"

# With options
reminder-cli create "Buy milk" \
  --list "Shopping" \
  --notes "Get 2% milk" \
  --start-date "2026-01-14" \
  --due-date "2026-01-15" \
  --priority 5 \
  --url "https://example.com/recipe"

# Date formats (applies to both --start-date and --due-date)
reminder-cli create "Task" --due-date "2026-01-15"           # Date only
reminder-cli create "Task" --due-date "2026-01-15 14:30"     # Date and time

# With URL
reminder-cli create "Read article" \
  --url "https://example.com/article" \
  --notes "Important article"
```

### Update a reminder

```bash
# Update title
reminder-cli update 29CC6D52 --title "Buy oat milk"

# Update notes and due date
reminder-cli update 29CC6D52 \
  --notes "Get organic" \
  --due-date "2026-01-16"

# Update priority (0=none, 1-4=high, 5=medium, 6-9=low)
reminder-cli update 29CC6D52 --priority 1

# Update start date and URL
reminder-cli update 29CC6D52 \
  --start-date "2026-01-14" \
  --url "https://example.com/store"
```

### Complete a reminder

```bash
reminder-cli complete 29CC6D52
```

### Delete a reminder

```bash
# With confirmation prompt
reminder-cli delete 29CC6D52

# Skip confirmation
reminder-cli delete 29CC6D52 --force
```

## Priority Levels

- `0` - No priority
- `1-4` - High priority (‼️)
- `5` - Medium priority (❗)
- `6-9` - Low priority (❕)

## Permissions

On first run, reminder-cli will request access to your Reminders. You'll see a system permission dialog. Grant access to allow the tool to manage your reminders.

## EventKit Limitations

While reminder-cli supports many Reminders.app features, some are not available through Apple's EventKit framework:

- **Flags** - The "flagged" indicator is not accessible via EventKit
- **Tags** - Introduced in iOS 15, but not exposed in EventKit API
- **Sections** - Introduced in iOS 17 / macOS Sonoma, but not exposed in EventKit API
- **Attachments** - Not accessible on EKReminder objects
- **Images** - Cannot be added or viewed through EventKit

These limitations are imposed by Apple's EventKit framework and affect all third-party reminder applications.

## Development

### Available Make Commands

```bash
make            # Show all available commands
make build      # Build debug version
make release    # Build release version
make install    # Build and install to ~/bin
make uninstall  # Remove from ~/bin
make clean      # Remove build artifacts
make run        # Build and run (debug)
make version    # Show Swift version info
make format     # Format code (requires swift-format)
```

### Manual Build

```bash
swift build                      # Debug build
swift build -c release          # Release build
.build/debug/reminder-cli list  # Run debug version
```

### Testing

```bash
swift test  # Run the unit test suite
```

Tests cover EventKit-independent logic only (`OutputFormatter`, date parsing, sort comparisons) since CI cannot grant Reminders access.

## License

[WTFPL](http://www.wtfpl.net/) - Do What The Fuck You Want To Public License

## Author

[yancya](https://github.com/yancya)
