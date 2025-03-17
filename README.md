# 🌽 Corn Field (cofi)

A simple terminal utility to manage and quickly access your frequently used config files.

## Demo

![cofi in action](./images/cofi.gif)

## Features
- Quickly access favorite config files
- Interactive terminal UI with vim-like keybindings
- Direct access to specific favorites via CLI

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
