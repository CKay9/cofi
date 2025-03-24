# 🌽 Cornfield (cofi)

**A cleaner alternative to maintaining aliases or scripts for configuration files**

Cofi is a lightweight, fast terminal utility that helps you manage and quickly access your configuration files. Stop digging through directories and remembering complex paths - cofi makes your most important config files easily accessible from anywhere in your terminal.

## Demo

![cofi in action](./images/cofi.gif)

## Key Features

- **Centralized Management**: Store all your important config files in one accessible place
- **Interactive TUI**: Clean terminal interface with vim-like navigation (j/k or arrow keys)
- **Customizable Organization**:
  - Add custom names to configs for easier identification
  - Organize configs with categories
  - Filter configurations by category
  - Color-code categories for visual distinction
- **Fast Access**:
  - Open favorites directly by index number (e.g., `cofi 2`)
  - Quick list view with `cofi -l` or `cofi --list`
- **Smart Editor Integration**:
  - Auto-detects preferred editor from environment variables
  - Customizable editor settings via the settings menu
- **Path Handling**: File path expansion with tilde (~) support
- **Sorting Options**: Sort by name or category, ascending or descending

## Installation

### Prerequisites
- [Zig 0.15.0-dev](https://ziglang.org/download/) or later
- A Unix-like operating system (Linux, macOS)
- On Linux systems, you'll need C development headers: install with `sudo pacman -S glibc base-devel` on Arch Linux or `sudo apt install build-essential` on Debian/Ubuntu

### Installation from Source
```bash
# Clone the repository
git clone https://github.com/CKay9/cofi.git
cd cofi

# Build the project
zig build

# Option 1: Install to your personal bin directory
mkdir -p ~/bin
cp zig-out/bin/cofi ~/bin/
chmod +x ~/bin/cofi

# Option 2: Install system-wide (requires sudo privileges)
sudo cp zig-out/bin/cofi /usr/local/bin/
sudo chmod +x /usr/local/bin/cofi
```

### Adding to PATH (Only needed for Option 1)
If you used Option 1 to install to your personal bin directory, make sure `~/bin` is in your PATH by adding this to your shell configuration file (`.bashrc`, `.zshrc`, etc.):

```bash
export PATH="$HOME/bin:$PATH"
```

After adding this line, reload your shell configuration:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

### Verifying Installation
To verify that cofi is properly installed, run:
```bash
cofi -v
```

This should display the version of cofi.

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

## Troubleshooting

### Command Not Found
If you get a "command not found" error after installation, make sure:
- The binary exists in the location you copied it to
- The location is in your PATH
- The binary has executable permissions (`chmod +x`)

### Build Errors on Linux
If you encounter build errors related to missing C headers, make sure you have the necessary development packages installed:
- Arch Linux: `sudo pacman -S glibc base-devel`
- Ubuntu/Debian: `sudo apt install build-essential`

## Contributing
Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
