# 🌽 Cornfield (cofi)

**A cleaner alternative to maintaining aliases or scripts**

Cofi is a lightweight, fast terminal utility for managing and accessing your configuration files. Stop digging through directories and remembering paths - cofi helps you find and quickly edit your most important config files.

## Demo

![cofi in action](./images/cofi.gif)

## Features

- Central management of all your configuration files
- Interactive terminal UI with vim-like keybindings (j/k navigation, arrow keys support)
- Add, view, and remove favorite config files via the interactive menu
- Add custom names to your config files for easier identification
- Organize configs with optional categories
- Filter configurations by category
- Directly open a specific favorite by index (e.g., `cofi 1`)
- Auto-detection of your preferred editor from environment variables
- Custom editor settings via the settings menu
- Quick list view of all your favorites with `cofi -l` or `cofi --list`
- File path expansion with tilde (~) support
- Clean, visual menus with intuitive navigation

## Installation

### Prerequisites
- [Zig 0.15.0-dev](https://ziglang.org/download/) or later
- A Unix-like operating system (Linux, macOS)

### Installation from Source
```bash
# Clone the repository
git clone https://github.com/CKay9/cofi.git
cd cofi

# Build the project
zig build

# Install to your bin directory
mkdir -p ~/bin
cp zig-out/bin/cofi ~/bin/
chmod +x ~/bin/cofi
```

### Adding to PATH
To use cofi from anywhere, make sure `~/bin` is in your PATH by adding this to your shell configuration file:

```bash
export PATH="$HOME/bin:$PATH"
```

## Usage

### Interactive Mode
To launch the interactive menu:
```bash
cofi
```

### Direct Access
To directly open a favorite config file by its index:
```bash
cofi 1  # Opens the first config file in your favorites
```

### List All Favorites
To quickly view all registered files:
```bash
cofi -l, --list
```

### Other Commands
```bash
cofi -h, --help     # Show help information
cofi -v, --version  # Display version information
```

### Keyboard Navigation
- `j` or down arrow - Move down in menus
- `k` or up arrow - Move up in menus
- `Enter` - Select item
- `q` - Quit/cancel current menu

## Configuration
Cofi stores your favorites in `~/.config/cofi/favorites.json` and settings in `~/.config/cofi/settings.json`. These files are automatically created on first run.

### Settings
You can customize your editor preference in the settings menu or directly edit the settings file. If no custom editor is set, cofi will use your `$EDITOR` environment variable or default to `nano`.

## Contributing
Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
