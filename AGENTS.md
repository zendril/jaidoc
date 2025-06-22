# AGENT GUIDELINES FOR JAIDOC REPOSITORY

This document outlines essential commands and code style for agents working in the `jaidoc` repository.

## 1. Build/Lint/Test Commands

- **Build:** `jai build.jai - build` (default)
- **Clean:** `jai build.jai clean`
- **Single Test:** There is no dedicated single test command. Tests are integrated into the build process.

## 2. Code Style Guidelines (Jai)

- **Imports:** Use `#import` at the top of files.
- **Formatting:** Consistent indentation (4 spaces or tabs).
- **Types:** Explicit type declarations.
- **Naming Conventions:**
    - Procedures/Functions: `snake_case`
    - Enums: `PascalCase` for enum, `UPPER_SNAKE_CASE` for flags.
    - Variables: `snake_case`
- **Error Handling:** Check return values for success/failure; use `exit(1)` for critical errors.
- **Comments:** Use `//` for single-line comments.

## 3. Cursor/Copilot Rules

No specific Cursor or Copilot rules found in the repository.
