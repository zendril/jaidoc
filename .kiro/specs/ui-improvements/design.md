# Design Document

## Overview

This design implements four UI improvements to the Jaidoc documentation generator:
1. Making the application title clickable for navigation
2. Displaying shortened file paths on the index page
3. Preventing automatic focus stealing by the search input
4. Adding configurable application title support

The changes will be implemented across the HTML generation, CSS styling, JavaScript functionality, and configuration system.

## Architecture

The implementation involves modifications to several key components:

- **Configuration Layer**: Extend `Jaidoc_Options` struct to support custom application title
- **HTML Generation Layer**: Modify `jaidoc_html.jai` to generate clickable titles and shortened paths
- **CSS Layer**: Update `jaidoc_css.jai` to style the clickable title appropriately
- **JavaScript Layer**: Modify search functionality to prevent automatic focus
- **Command Line Interface**: Update argument parsing to accept custom title parameter

## Components and Interfaces

### 1. Configuration Component

**File**: `src/jaidoc/jaidoc_types.jai`

The `Jaidoc_Options` struct will be extended with a new field:
```jai
Jaidoc_Options :: struct {
    output_directory: string = "docs";
    project_root: string = "";
    log_level: LogLevel = .DEFAULT;
    app_title: string = "Jaidoc";  // New field for custom title
}
```

### 2. HTML Generation Component

**File**: `src/jaidoc/jaidoc_html.jai`

The `generate_html_page` function will be modified to:
- Accept the app title as a parameter
- Generate clickable title HTML with proper href attribute
- Implement path shortening logic for index page file listings

**Key Functions to Modify**:
- `generate_html_page()`: Add app_title parameter and generate clickable title
- Add new helper function `shorten_file_path()`: Convert absolute paths to relative paths
- Modify index page generation logic to use shortened paths

### 3. CSS Styling Component

**File**: `src/jaidoc/jaidoc_css.jai`

Add CSS rules for:
- Clickable title styling (cursor pointer, hover effects)
- Maintaining visual consistency with existing design
- Ensuring accessibility for the clickable element

### 4. JavaScript Search Component

**File**: Generated `search.js` in HTML output

Modify the search initialization to:
- Remove any automatic focus setting on page load
- Ensure focus only occurs on explicit user interaction
- Maintain existing search functionality without interference

### 5. Command Line Processing Component

**File**: `build.jai` and plugin integration points

Add support for parsing custom title from command line arguments:
- Accept `-title "Custom Title"` or similar parameter
- Pass the title through to `Jaidoc_Options`

## Data Models

### Path Processing Model

```jai
Path_Info :: struct {
    absolute_path: string;
    relative_path: string;
    display_path: string;
}
```

The path shortening logic will:
1. Take the absolute file path
2. Remove the project root prefix
3. Normalize path separators
4. Return the shortened relative path

### Title Configuration Model

The application title will be configurable through:
1. Command line argument (highest priority)
2. Default value in `Jaidoc_Options` (fallback)

## Error Handling

### Path Shortening Errors
- If project root cannot be determined, fall back to filename only
- Handle edge cases where paths don't contain the project root
- Ensure path separators are normalized across platforms

### Title Configuration Errors
- If custom title is empty or invalid, fall back to "Jaidoc"
- Properly escape HTML special characters in custom titles
- Handle very long titles gracefully in the UI

### Search Focus Errors
- Ensure search functionality remains intact after removing auto-focus
- Handle cases where search input element is not found
- Maintain backward compatibility with existing search behavior



## Implementation Phases

### Phase 1: Configuration and Path Shortening
- Extend `Jaidoc_Options` with app_title field
- Implement path shortening logic
- Update index page generation to use shortened paths

### Phase 2: Clickable Title Implementation
- Modify HTML generation to create clickable title
- Add appropriate CSS styling
- Test navigation functionality

### Phase 3: Search Focus Prevention
- Modify search JavaScript to remove auto-focus
- Test text selection functionality
- Ensure search remains fully functional

### Phase 4: Command Line Integration
- Add command line argument parsing for custom title
- Update build script integration examples
- Test end-to-end with custom titles

## Security Considerations

- **HTML Injection Prevention**: All custom titles must be properly HTML-escaped
- **Path Traversal Prevention**: Ensure path shortening doesn't expose sensitive directory information
- **XSS Prevention**: Validate and sanitize any user-provided title input

## Performance Considerations

- Path shortening operations should be minimal and cached where possible
- HTML generation performance should not be significantly impacted
- Search functionality performance must remain unchanged