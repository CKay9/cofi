# 🌽 cofi

**A fast terminal utility for configuration file management, built with Zig**

cofi is a fast terminal utility that helps you manage and quickly access your configuration files. It eliminates the need to navigate complex directory structures or remember long paths when accessing frequently used config files.

## Key Features

- **Fast Access**: Open any saved config file with `cofi <number>`
- **Terminal Interface**: Clean TUI with vim-like navigation (j/k or arrow keys)
- **Organization Features**:
  - Custom names for easier identification
  - Category-based grouping
  - Color-coding for visual distinction
- **Technical Advantages**:
  - Built with Zig for exceptional speed and reliability
  - Single executable with no dependencies
  - Integration with your preferred editor ($EDITOR)
  - Fast startup time
  - Path handling with tilde (~) expansion

## Demo

![cofi in action](./images/cofi.gif)

## Installation

### Prerequisites
- [Zig 0.15.0-dev](https://ziglang.org/download/) or later
- A Unix-like operating system (Linux, macOS)
- On Linux: `sudo pacman -S glibc base-devel` (Arch) or `sudo apt install build-essential` (Debian/Ubuntu)

### Installation from Source
```bash
# Clone the repository
git clone https://github.com/CKay9/cofi.git
cd cofi

# Build the project
zig build

# Install to your personal bin directory
mkdir -p ~/bin
cp zig-out/bin/cofi ~/bin/
chmod +x ~/bin/cofi

# Add to PATH if needed
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc  # or your shell's config
```

### Verifying Installation
```bash
cofi -v  # Should display the version number
```

## Usage

### Basic Commands
```bash
cofi           # Start the interactive menu
cofi 3         # Directly open config with ID 3
cofi -l        # List all registered files
cofi -h        # Show help information
cofi -v        # Display version information
```

### Navigation
- `j` or down arrow - Move down 
- `k` or up arrow - Move up
- `Enter` - Select item
- `q` - Quit/back

## Workflow

1. Add frequently used configuration files through the interactive menu
2. View your saved configs with `cofi -l` to see their assigned IDs
3. Access any config directly using `cofi <id>`
4. Organize configs with categories for logical grouping
5. Add custom names for easier identification

## Configuration

cofi stores its data in:
- `~/.config/cofi/favorites.json` - Your saved configuration files
- `~/.config/cofi/settings.json` - cofi's settings

These files use a straightforward JSON format that can be edited manually if needed.

## Troubleshooting

### Command Not Found
- Ensure cofi's location is in your PATH
- Verify the binary has executable permissions (`chmod +x`)

### Build Errors on Linux
- Install the required development packages:
  - Arch Linux: `sudo pacman -S glibc base-devel`
  - Ubuntu/Debian: `sudo apt install build-essential`

## Contributing
Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
