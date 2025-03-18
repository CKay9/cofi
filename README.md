# 🌽 Cornfield (cofi)

A lightweight, fast terminal utility for managing and accessing your configuration files. Stop digging through directories and remembering paths - cofi helps you find and quickly edit your most important config files.

## Demo

![cofi in action](./images/cofi.gif)

## Features
- Add paths to config files via the Favorites menu
- Quickly access favorite config files
- Interactive terminal UI with vim-like keybindings
- Directly open any config file on your computer with a short command
- Automatically uses your favorite editor, as defined in environment variables

## Installation

### Prerequisites
- Zig 0.15.0-dev or later

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

Once you have added config files, directly open them with a short command. 
To access the first item in the list, simply type:
```bash
cofi 1
```
**More features coming soon!**

