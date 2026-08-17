# Contributing to Kamidana

Thank you for your interest in contributing to **Kamidana**! 

Kamidana is an open-source, customizable, native status bar application for macOS, inspired by [YASB (Yet Another Status Bar)](https://github.com/amnweb/yasb). We are actively developing towards our **v1.0 release** and welcome contributions ranging from bug fixes and new widgets to architectural improvements and documentation.

---

## Table of Contents
- [Getting Started](#getting-started)
- [Finding Tasks](#finding-tasks)
- [Development Environment](#development-environment)
- [Code Guidelines & Standards](#code-guidelines--standards)
- [Pull Request Process](#pull-request-process)
- [Use of AI Tools](#use-of-ai-tools)
- [Community & Discussions](#community--discussions)

---

## Getting Started

1. **Fork the Repository**: Fork [dreaminbb/Kamidana](https://github.com/dreaminbb/Kamidana) to your GitHub account and clone it locally:
   ```bash
   git clone https://github.com/<your-username>/Kamidana.git
   cd Kamidana
   ```
2. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

---

## Finding Tasks

- **GitHub Issues**: Check the [Issues tab](../../issues) for open tasks. Look for:
  - `good first issue` — Tasks suitable for newcomers to the project.
  - `help wanted` — Tasks where we actively seek community contributions.
  - `enhancement` — New features or improvements.
  - `bug` — Known bugs that need resolving.
- **Roadmap & Project Board**: See our [Process for 1.0 release Project Board](https://github.com/users/dreaminbb/projects/11) for current milestones and roadmap items.
- **Claim an Issue**: Before starting work, **please comment on the issue** to express your interest and claim it. This prevents duplicate efforts across contributors.

---

## Development Environment

### Requirements
- **OS**: macOS 14.0 (Sonoma) or newer
- **Toolchain**: Swift 6.0+ (Xcode 15.0+ or Command Line Tools)
- **Fonts**: A Nerd Font installed (e.g., [JetBrainsMono Nerd Font](https://www.nerdfonts.com/))

### Common Commands

We use a `Makefile` to simplify common development tasks:

```bash
# Run the app directly in development mode
make run

# Build the standalone macOS .app bundle with code signing
make app

# Run in debug mode with live terminal logging
make debug

# Clean build artifacts and .app bundle
make clean
```

---

## Code Guidelines & Standards

To ensure the codebase remains maintainable, portable, and accessible to international contributors, please adhere to the following conventions:

### 1. English Only
- All code identifiers, comments (`//`, `///`), docstrings, commit messages, and log messages **must be written in English**.

### 2. No Emojis in Source Code & Logs
- **Do not use emojis** in code comments, console prints, or log strings. Keep log messages professional, clean, and concise (e.g., `[BluetoothManager] Device disconnected:` instead of `❌ disconnected : ...`).

### 3. Portability & No Hardcoded Paths
- Never hardcode user-specific paths (e.g., `/Users/username/...`).
- Use dynamic resource resolution (`Bundle.main.resourcePath`, `Bundle.main.bundlePath`, `FileManager.default`, or relative fallback paths).

### 4. Icon Component (`NerdFontIcon`)
- Use the `NerdFontIcon` component for all UI symbols.
- Icons are centrally mapped in [`nerdfont.toml`](nerdfont.toml).
- Always pass the size directly to the constructor rather than chaining `.font(...)`:
  ```swift
  // Recommended
  NerdFontIcon(.music, size: 16)

  // Avoid
  NerdFontIcon(.music).font(.system(size: 16))
  ```

### 5. Logging Cleanliness
- Avoid noisy, continuous polling print statements (such as prints fired on every 1-second timer tick). Keep terminal output informative and minimal.

### 6. App Lifecycle & Memory Management
- When interacting with AppKit delegates and window managers, be mindful of `weak` references (such as `NSApplication.shared.delegate`) to prevent premature deallocation during release builds.

---

## Pull Request Process

1. **Keep PRs Focused**: Submit one feature or bug fix per Pull Request. Avoid bundling unrelated refactors into a single PR.
2. **Verify Builds**: Ensure your code builds cleanly with both `make run` and `make app` without warnings or regressions.
3. **Describe Your Changes**:
   - What changed?
   - Why was this change made?
   - How can reviewers test and verify it?
   - Link the relevant issue (e.g., `Closes #12`).
4. **Code Review**: Be open to reviewer feedback. Iterative collaboration is part of the development process.

---

## Use of AI Tools

AI coding assistants (Claude, ChatGPT, GitHub Copilot, etc.) are welcome in this project under the following conditions:

- **Full Understanding**: You must understand and be able to explain every line of code you submit.
- **Review & Test**: Never paste raw AI outputs blindly. Review, refine, and test your code locally before opening a PR.
- **Responsibility**: You are fully responsible for correctness, performance, safety, and licensing of all submitted code.
- **Disclosure**: If a significant portion of the PR was generated using AI tools, please disclose it in the PR description.

---

## Community & Discussions

- If you have an idea for a feature or an architectural proposal, open an **Issue** or **Discussion** first to align on design before spending significant time coding.
- Treat all community members with respect and professionalism.

Thank you for helping make Kamidana awesome!
