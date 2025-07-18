# Requirements Document

## Introduction

The current search functionality in the Jaidoc documentation system uses a basic implementation in `src/jaidoc/assets/js/search.js` that searches only page titles from a simple JSON index. The system uses Fuse.js for fuzzy searching but is limited to title-only searches with basic link display. This enhancement will expand the search to include full-text content from documentation pages (headers, procedure names, variable names, code snippets, etc.) and provide a modern, keyboard-navigable search results interface with improved visual presentation. The solution must work with the existing static HTML generation and modify only the JavaScript files in `src/jaidoc/assets/js` without requiring npm or additional library installations.

## Requirements

### Requirement 1

**User Story:** As a developer browsing documentation, I want to search across all text content including headers, procedure names, variable names, and code snippets, so that I can find relevant information even when I don't know the exact page title.

#### Acceptance Criteria

1. WHEN a user types in the search box THEN the system SHALL search across page titles, headers (h1-h6), procedure names, variable names, union names, and visible text content
2. WHEN searching for a procedure name like "speak_poetry" THEN the system SHALL return the page containing that procedure with relevant context
3. WHEN searching for a variable name like "module_status_code" THEN the system SHALL return the page containing that variable with relevant context
4. WHEN searching for header text like "Procedures" or "Global Variables" THEN the system SHALL return pages containing those sections
5. IF a search term appears in multiple content types on the same page THEN the system SHALL prioritize the result based on content type relevance (exact matches > headers > procedure names > general content)

### Requirement 2

**User Story:** As a developer using the documentation search, I want search results displayed in a visually appealing, structured list with proper styling, so that I can easily scan and identify the most relevant results.

#### Acceptance Criteria

1. WHEN search results are displayed THEN they SHALL appear in a styled dropdown/list container with proper spacing, borders, and background colors matching the dark theme
2. WHEN displaying each search result THEN it SHALL show the page title, content type (e.g., "Procedure", "Variable", "Header"), and a brief context snippet
3. WHEN multiple results are available THEN each result SHALL be visually separated with consistent styling
4. WHEN no results are found THEN the system SHALL display a "No results found" message in the styled container
5. WHEN the search input is empty THEN the results container SHALL be hidden

### Requirement 3

**User Story:** As a developer navigating search results, I want to use keyboard controls (arrow keys, enter) to navigate and select results, so that I can efficiently browse documentation without using the mouse.

#### Acceptance Criteria

1. WHEN search results are displayed THEN the user SHALL be able to navigate through results using up/down arrow keys
2. WHEN a result is highlighted via keyboard navigation THEN it SHALL have a distinct visual highlight/focus state
3. WHEN the user presses Enter on a highlighted result THEN the system SHALL navigate to that page
4. WHEN the user presses Escape THEN the search results SHALL be hidden and focus SHALL return to the search input
5. WHEN navigating past the last result with down arrow THEN focus SHALL wrap to the first result
6. WHEN navigating past the first result with up arrow THEN focus SHALL wrap to the last result

### Requirement 4

**User Story:** As a developer reviewing search results, I want to see a limited number of results (5) initially with the ability to scroll through additional results, so that the interface remains clean while still providing access to all relevant matches.

#### Acceptance Criteria

1. WHEN search results are displayed THEN the system SHALL show a maximum of 5 results initially in the visible area
2. WHEN more than 5 results are available THEN the results container SHALL be scrollable to view additional results
3. WHEN scrolling through results THEN the container SHALL maintain a fixed height and provide smooth scrolling
4. WHEN keyboard navigation reaches results outside the visible area THEN the container SHALL automatically scroll to keep the focused result visible
5. WHEN the total number of results exceeds 20 THEN the system SHALL limit results to the top 20 most relevant matches

### Requirement 5

**User Story:** As a developer using the search functionality, I want mouse interaction support for selecting results, so that I can choose my preferred interaction method between keyboard and mouse.

#### Acceptance Criteria

1. WHEN hovering over a search result with the mouse THEN the result SHALL show a hover state with visual feedback
2. WHEN clicking on a search result THEN the system SHALL navigate to that page
3. WHEN both keyboard and mouse interactions are used THEN the system SHALL maintain consistent visual states and behavior
4. WHEN mouse hover occurs during keyboard navigation THEN the mouse hover SHALL take precedence for visual highlighting
5. WHEN clicking outside the search results area THEN the results SHALL be hidden