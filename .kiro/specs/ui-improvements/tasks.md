# Implementation Plan

- [x] 1. Extend configuration system to support custom application title





  - Add app_title field to Jaidoc_Options struct in jaidoc_types.jai
  - Set default value to "Jaidoc" to maintain backward compatibility
  - _Requirements: 4.3, 4.5_

- [x] 2. Implement path shortening functionality for index page





  - [x] 2.1 Create path shortening helper function


    - Write shorten_file_path function that removes project root prefix from absolute paths
    - Handle edge cases where project root is not found in path
    - Normalize path separators for cross-platform compatibility
    - _Requirements: 2.1, 2.2, 2.4_

  - [x] 2.2 Update index page generation to use shortened paths


    - Modify index page file listing generation in generate_html_docs function
    - Apply path shortening to main program files display
    - Ensure consistency with individual page path display format
    - _Requirements: 2.1, 2.2, 2.3_

- [x] 3. Implement clickable application title functionality





  - [x] 3.1 Modify HTML generation to create clickable title


    - Update generate_html_page function to accept app_title parameter
    - Replace static "Jaidoc" text with clickable anchor element linking to index.html
    - Properly escape HTML special characters in custom titles
    - _Requirements: 1.1, 4.1, 4.4, 4.5_

  - [x] 3.2 Add CSS styling for clickable title


    - Add hover effects and cursor pointer for title link
    - Maintain existing visual appearance while indicating clickability
    - Ensure accessibility compliance for the clickable element
    - _Requirements: 1.2_

  - [x] 3.3 Update all HTML generation calls to pass app_title


    - Modify generate_html_docs function to pass app_title to generate_html_page
    - Update index page, file pages, and module pages generation
    - Ensure consistent title display across all pages
    - _Requirements: 1.1, 1.3, 4.1, 4.4_

- [x] 4. Remove automatic focus from search input





  - [x] 4.1 Modify search JavaScript to prevent auto-focus


    - Update search.js generation in generate_html_docs function
    - Remove any automatic focus setting on page load
    - Ensure focus only occurs when user explicitly clicks on search input
    - _Requirements: 3.1, 3.2, 3.5_

  - [x] 4.2 Test and verify search functionality remains intact


    - Ensure search results display correctly without auto-focus
    - Verify keyboard navigation and manual focus still work
    - Test that text selection is no longer interrupted
    - _Requirements: 3.3, 3.4_

- [ ] 5. Add command line argument support for custom title
  - [ ] 5.1 Update build.jai to parse custom title argument
    - Add parsing logic for -title command line argument
    - Pass custom title to Jaidoc_Options when provided
    - Maintain backward compatibility when no title is specified
    - _Requirements: 4.1, 4.2, 4.3_

  - [ ] 5.2 Update plugin integration to support title parameter
    - Modify jaidoc_processor.jai to handle title configuration
    - Ensure plugin mode can accept and use custom titles
    - Test integration with existing build scripts
    - _Requirements: 4.1, 4.2_

- [ ] 6. Create comprehensive tests for all functionality
  - [ ] 6.1 Write unit tests for path shortening logic
    - Test various absolute path formats and project root combinations
    - Test edge cases with invalid or missing project roots
    - Verify cross-platform path separator handling
    - _Requirements: 2.1, 2.2, 2.4_

  - [ ] 6.2 Write integration tests for HTML generation
    - Test clickable title HTML structure and navigation
    - Verify shortened paths appear correctly on index page
    - Test custom title display and HTML escaping
    - _Requirements: 1.1, 1.2, 2.1, 4.4, 4.5_

  - [ ] 6.3 Write tests for search functionality
    - Verify search works without automatic focus
    - Test that text selection is not interrupted by search
    - Ensure manual search input focus still functions
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_