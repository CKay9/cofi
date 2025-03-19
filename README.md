# 🌽 Cornfield (cofi)

**A cleaner alternative to maintaining aliases or scripts**

Cofi is a lightweight, fast terminal utility for managing and accessing your configuration files. Stop digging through directories and remembering paths - cofi helps you find and quickly edit your most important config files.

## Demo

![cofi in action](./images/cofi.gif)

## Features

- Central management of all your configuration files
- Interactive terminal UI with vim-like keybindings (j/k for navigation)
- Add, view, and remove favorite config files via the interactive menu
- Add custom names to your config files for easier identification
- Organize configs with optional categories
- Directly open a specific favorite by index (e.g., `cofi 1`)
- Auto-detection of your preferred editor from environment variables
- Clean, visual menus with intuitive navigation

## Installation

### Prerequisites
- Zig 0.15.0-dev or later
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

### Other Commands
```bash
cofi -h, --help     # Show help information
cofi -v, --version  # Display version information
```

### Keyboard Navigation
- `j` - Move down in menus
- `k` - Move up in menus
- `Enter` - Select item
- `q` - Quit/cancel current menu

## Configuration
Cofi stores your favorites in `~/.config/cofi/favorites.json`. This file is automatically created on first run.

## Contributing
Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
