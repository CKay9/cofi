# Contributing to cofi

Thank you for your interest in contributing to cofi! This document provides guidelines and instructions for contributing to this project.

## Getting Started

### Prerequisites

- [Zig 0.15.0-dev](https://ziglang.org/download/)
- A Unix-like operating system (Linux, macOS)
- Basic understanding of terminal applications

### Setting Up the Development Environment

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```
   git clone https://github.com/YOUR_USERNAME/cofi.git
   cd cofi
   ```
3. Build the project:
   ```
   zig build
   ```
4. Run the application:
   ```
   ./zig-out/bin/cofi
   ```

## Development Workflow

### Branch Strategy

- `main` branch is the stable version
- Create feature branches from `main` for new features or bug fixes
- Use descriptive names for your branches (e.g., `add-config-search` or `fix-terminal-restore`)

### Making Changes

1. Create a new branch for your changes
2. Make your changes in the new branch
3. Test your changes thoroughly
4. Commit your changes with descriptive commit messages

### Code Style

- Follow the existing code style in the project
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused on a single task

### Submitting Changes

1. Push your changes to your fork on GitHub
2. Create a pull request from your branch to the main repository
3. Describe your changes in the pull request, including any relevant information
4. Wait for review and address any feedback

## Project Structure

- `src/main.zig`: The main entry point for the application
- `src/modules/`: Directory containing auxiliary modules
  - `favorites.zig`: Module for managing favorite config files

## Known Issues and Future Improvements

Current known issues:
- Terminal settings may not be properly restored if an error occurs

Planned future improvements:
- Search functionality for config files
- Categories for organization
- Config file editing history

## Communication

If you have questions or need help, please:
- Open an issue on GitHub
- Comment on the relevant pull request
- Contact the maintainer directly if appropriate

## License

By contributing to this project, you agree that your contributions will be licensed under the project's license.

Thank you for contributing to cofi!
