# reminder-cli

A Swift-based command-line tool to manage iCloud Reminders on macOS.

## Features

- 📋 **List** - View all reminders or filter by specific list
- 🔍 **Show** - Display detailed information about a reminder
- ➕ **Create** - Add new reminders with notes, due dates, and priority
- ✏️ **Update** - Modify existing reminders
- 🗑️ **Delete** - Remove reminders (with confirmation prompt)
- ✅ **Complete** - Mark reminders as done

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later
- Xcode (for building)

## Installation

Clone the repository and build:

```bash
git clone https://github.com/yancya/reminder-cli.git
cd reminder-cli
swift build -c release
```

The built executable will be at `.build/release/reminder-cli`.

Optionally, copy it to your PATH:

```bash
cp .build/release/reminder-cli /usr/local/bin/
```

## Usage

### List reminders

```bash
# List all reminders from all lists
reminder-cli list

# List reminders from a specific list
reminder-cli list "Shopping"

# Include completed reminders
reminder-cli list --completed
```

### Show reminder details

```bash
# By title
reminder-cli show "Buy milk"

# By ID
reminder-cli show 29CC6D52-D95F-43D1-BF77-0777374C8D93
```

### Create a new reminder

```bash
# Simple reminder
reminder-cli create "Buy milk"

# With options
reminder-cli create "Buy milk" \
  --list "Shopping" \
  --notes "Get 2% milk" \
  --due-date "2026-01-15" \
  --priority 5

# Due date formats
reminder-cli create "Task" --due-date "2026-01-15"           # Date only
reminder-cli create "Task" --due-date "2026-01-15 14:30"     # Date and time
```

### Update a reminder

```bash
# Update title
reminder-cli update "Buy milk" --title "Buy oat milk"

# Update notes and due date
reminder-cli update "Buy milk" \
  --notes "Get organic" \
  --due-date "2026-01-16"

# Update priority (0=none, 1-4=high, 5=medium, 6-9=low)
reminder-cli update "Buy milk" --priority 1
```

### Complete a reminder

```bash
reminder-cli complete "Buy milk"
```

### Delete a reminder

```bash
# With confirmation prompt
reminder-cli delete "Buy milk"

# Skip confirmation
reminder-cli delete "Buy milk" --force
```

## Priority Levels

- `0` - No priority
- `1-4` - High priority (‼️)
- `5` - Medium priority (❗)
- `6-9` - Low priority (❕)

## Permissions

On first run, reminder-cli will request access to your Reminders. You'll see a system permission dialog. Grant access to allow the tool to manage your reminders.

## Development

### Build

```bash
swift build
```

### Run without installing

```bash
.build/debug/reminder-cli list
```

## License

MIT

## Author

[yancya](https://github.com/yancya)
