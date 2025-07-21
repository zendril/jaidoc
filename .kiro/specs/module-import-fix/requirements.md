# Requirements Document

## Introduction

The jaidoc codebase currently operates in two modes: as a metaprogram (via build.jai) and as a plugin. While the metaprogram mode works correctly, the plugin mode encounters an error where it cannot find the 'jaidoc' module, even when using the `--- import_dir .` flag. This is because there is no 'modules' directory in the project structure. This feature aims to fix the module import mechanism for the plugin mode to ensure it works correctly without requiring users to modify their directory structure.

## Requirements

### Requirement 1: Plugin Module Import Fix

**User Story:** As a Jai developer, I want to use jaidoc as a plugin without encountering module import errors, so that I can easily generate documentation for my projects.

#### Acceptance Criteria

1. WHEN running jaidoc in plugin mode with `+jaidoc` THEN the system SHALL correctly locate and import the jaidoc module without errors.
2. WHEN using the plugin without any additional import flags THEN the system SHALL still work correctly.
3. IF the jaidoc module is not in the standard module path THEN the system SHALL provide clear error messages with instructions on how to resolve the issue.
4. WHEN the plugin is used with `--- import_dir .` THEN the system SHALL correctly find and use the module.

### Requirement 2: Consistent Module Structure

**User Story:** As a maintainer of the jaidoc codebase, I want a consistent module structure that works in both metaprogram and plugin modes, so that I can maintain a single codebase without duplication.

#### Acceptance Criteria

1. WHEN the codebase is used as a metaprogram THEN the system SHALL continue to work as before without any regression.
2. WHEN the codebase is used as a plugin THEN the system SHALL use the same core code as the metaprogram mode.
3. IF changes are made to the module structure THEN the system SHALL maintain backward compatibility with existing integrations.
4. WHEN a user follows the documentation for either usage mode THEN the system SHALL work without requiring additional configuration.

### Requirement 3: Documentation Updates

**User Story:** As a user of jaidoc, I want clear documentation on how to use it in both metaprogram and plugin modes, so that I can choose the appropriate method for my project.

#### Acceptance Criteria

1. WHEN reading the documentation THEN users SHALL find clear instructions for using jaidoc as a plugin.
2. WHEN reading the documentation THEN users SHALL find clear instructions for using jaidoc as a metaprogram.
3. IF there are special requirements for either mode THEN the documentation SHALL clearly explain these requirements.
4. WHEN users encounter issues with module imports THEN the documentation SHALL provide troubleshooting guidance.