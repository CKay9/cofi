# 🌽 cofi

**A lightning-fast terminal utility for configuration file management**

cofi eliminates the need to remember long paths or navigate complex directory structures to access your configuration files. Built with Zig for exceptional performance, it provides instant access to your most important configs.

## Features

- **Instant Access**: Open any saved config file with `cofi <id>`
- **Smart Organization**:
  - Category-based grouping with color coding
  - Custom naming for easier identification
  - File type icons for visual recognition
- **Efficient Navigation**: vim-style controls (j/k, g/G)
- **Seamless Integration**: Uses your preferred editor ($EDITOR)

![cofi in action](./images/cofi.gif)

## Usage

```bash
cofi              # Open interactive TUI menu
cofi 3            # Directly open config with ID 3
cofi -l           # List all registered config files
cofi -h           # Show help information
```

### Navigation Controls
- `j` or `↓` - Move down
- `k` or `↑` - Move up
- `g` - Jump to first item
- `G` - Jump to last item
- `Enter` - Select item/open file
- `m` - Access main menu
- `a` - Add new config file
- `d` - Delete selected config file
- `q` - Quit/go back

## Installation

### Prerequisites
- [Zig 0.15.0-dev](https://ziglang.org/download/) or later
- Unix-like operating system (Linux, macOS)

### Quick Install
```bash
git clone https://github.com/CKay9/cofi.git
cd cofi
zig build
# Install to your PATH
cp zig-out/bin/cofi ~/bin/
```

## Configuration

cofi stores its data in:
- `~/.config/cofi/favorites.json` - Your saved configuration files
- `~/.config/cofi/settings.json` - cofi settings (editor, sort order, colors)

## Why cofi?

- **Speed**: Zero startup latency, built with performance in mind
- **Simplicity**: Single binary with no dependencies
- **Workflow Enhancement**: Dramatically speeds up config file access

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
