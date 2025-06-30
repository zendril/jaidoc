# Jaidoc - Jai Documentation Generator Plan

This document outlines the development plan for `jaidoc`, a utility to generate documentation for Jai codebases. The development will proceed in checkpoints, allowing for review and adjustments at each stage.

## Overall Goals:
- [ ] Create a Jai compiler plugin (`+jaidoc`) to extract metaprogramming information.
- [ ] Generate documentation in Markdown and HTML formats.
- [x] Provide a sample application to demonstrate and test `jaidoc`.
- [ ] Incorporate features like doc comments and executable test cases in later stages.
- [x] Follow a standard project structure (`/src`, `/target`, `build.jai`).

## Checkpoints:

**Checkpoint 1: Initial Project Setup & Sample Application**
- **Objective:** Establish the basic project structure and a minimal sample Jai application.
- **Tasks:**
    - [x] Create the root `build.jai` file.
        - [x] Implement `clean` and `release` build stages.
        - [x] Define source directory as `/src` and output directory as `/target`.
    - [x] Create a `src/sample` directory (adjusted from `sample_app`).
    - [x] Inside `src/sample`, create a `sample.jai` file (adjusted from `sample_app/first.jai`):
        - [x] Implement a simple command-line application.
        - [x] Include a few public procedures.
        - [x] This app should compile and run successfully.
- **Deliverables:**
    - `build.jai` at the project root.
    - `src/sample/sample.jai` runnable application.
    - Directory structure:
        ```
        /
        |- build.jai
        |- src/
        |  |- sample/
        |  |  |- sample.jai
        |- target/   (for build outputs)
        ```
- **Review:** Verify project structure, build script functionality, and sample app execution. (Marked as complete by USER)

**Checkpoint 2: Basic Plugin Implementation**
- **Objective:** Create a minimal `jaidoc` plugin that can be loaded by the Jai compiler.
- **Tasks:**
    - [x] Create a `jaidoc_plugin` directory.
    - [x] Inside `jaidoc_plugin`, develop a basic Jai plugin (e.g., `plugin.jai`).
        - [x] Refer to `@reference/jai_autodoc` for plugin structure.
        - [x] The plugin, when loaded (e.g., `jai build.jai +jaidoc` or by building `src/sample/sample.jai` with the plugin flag), should indicate it has been loaded successfully (e.g., print a message to the console).
- **Deliverables:**
    - `jaidoc_plugin/plugin.jai` (or similar).
    - Demonstration that the plugin can be loaded by the Jai compiler when building `src/sample/sample.jai`.
- **Review:** Confirm the plugin loads correctly without errors.

**Checkpoint 3: Plugin Metaprogramming - Data Extraction**
- **Objective:** Enhance the plugin to extract metaprogramming information from the `src/sample/sample.jai`.
- **Tasks:**
    - [x] Modify the `jaidoc_plugin` to use Jai's metaprogramming capabilities.
        - [x] Refer to `@reference/jaicompiler` (specifically modules, examples, how-to for metaprogramming features).
    - [x] When the plugin is run on `src/sample/sample.jai`, it should:
        - [x] Traverse the Abstract Syntax Tree (AST) or relevant metaprogramming structures.
        - [x] Extract information about public declarations (procedures, structs, enums, etc. as available in `src/sample/sample.jai`).
        - [x] Print the extracted information to the console in a readable format.
    - [x] Extract core logic from `jaidoc_plugin/jaidoc.jai` into a reusable library:
        - [x] Create `jaidoc_processor.jai` with extracted message processing logic.
        - [x] Update `jaidoc_plugin/jaidoc.jai` to use the library.
        - [x] Update `build.jai` to call the library directly when running `jai build.jai`.
        - [x] Ensure both `jai build.jai` and `jai src\sample\sample.jai +jaidoc` work correctly.
    - [x] Expand `src/sample/sample.jai` to include:
        - [x] At least one public struct.
        - [x] At least one public enum.
    - [x] Build a data model for the documentation:
        - [x] Track imported modules.
        - [x] For each module, track the files it contains.
        - [x] For each file, track declarations (variables, procedures, enums, unions).
        - [x] This model will be the input for the Markdown generation in Checkpoint 4.
- **Deliverables:**
    - Updated `jaidoc_plugin` capable of extracting and printing metaprogramming data.
    - Updated `src/sample/sample.jai` with diverse public declarations.
    - Console output showing the extracted metaprogramming information.
- **Review:** Verify the accuracy and completeness of the extracted metaprogramming data.

**Checkpoint 4: Markdown Output - Main Screen**
- **Objective:** Generate basic Markdown documentation focusing on the main screen layout.
- **Tasks:**
    - [x] Design the Markdown structure based on the "main-screen" mockup from `@reference/figma-mockups`.
    - [x] Modify `jaidoc_processor` to process the extracted metaprogramming data and generate Markdown files.
    - [x] Output Markdown files to a directory specified by Jaidoc_Options.output_directory.
    - [x] The initial Markdown should cover:
        - [x] A main index page.
        - [x] Separate pages or sections for modules/files.
        - [x] Listings of public procedures, structs, enums with their signatures/definitions.
    - [ ] Implement (or pull in something like https://github.com/alourencodev/logssaurus) to do logging so we can have verbose, quiet, and normal modes.
- **Deliverables:**
    - `jaidoc_plugin` that generates Markdown documentation.
    - Sample Markdown output for `src/sample/sample.jai`.
- **Review:** Assess the generated Markdown for accuracy, completeness, and adherence to the main-screen mockup.

**Checkpoint 5: HTML Output - Main Screen**
- **Objective:** Generate HTML documentation based on the "main-screen" mockup.
- **Tasks:**
    - [x] Choose a method for HTML generation (e.g., convert Markdown to HTML, or generate HTML directly from metaprogramming data).
    - [x] Implement HTML generation in `jaidoc_plugin` or as a separate step in `build.jai`.
    - [x] Output HTML files to a designated directory (e.g., `target/docs/html`).
    - [x] Style the HTML to match the "main-screen" mockup.
    - [ ] Allow the user of this library to pass in the name to appear in the top left.
- **Deliverables:**
    - `jaidoc_plugin` (or build process) that generates HTML documentation.
    - Sample HTML output for `src/sample/sample.jai`.
- **Review:** Check the HTML output for visual accuracy against the mockup, correctness of content, and basic usability.

**Checkpoint 6: HTML Output - Search Screen**
- **Objective:** Implement the HTML "search-screen" functionality.
- **Tasks:**
    - [ ] Develop the HTML, CSS, and potentially JavaScript for the search interface based on the "search-screen" mockup.
    - [ ] Integrate the search functionality with the data generated in Checkpoint 5.
- **Deliverables:**
    - Functional HTML search screen for the generated documentation.
- **Review:** Test the search functionality for accuracy and usability.

**Future Checkpoints (To Be Detailed):**

- **Checkpoint 7: Doc Comment Support**
    - [x] Research Jai's existing comment conventions and popular doc comment styles (e.g., `///`, `//!`).
    - [ ] It appears doc comments are not supported by the compiler we will need to manually implement parsing of the source and correlate to the declarations.
        - [ ] 1. Parse comments manually from the source files
        - [ ] 2. Use location information to associate comments with nearby declarations
        - [ ] 3. Implement heuristics like:
            - [ ] Comments immediately before a declaration belong to it
            - [ ] Comments on the same line as a declaration belong to it
            - [ ] Multi-line comments above a declaration belong to it
    - [ ] Integrate extracted doc comments into Markdown and HTML outputs.
    - [ ] Expand `src/sample/sample.jai` with examples of documented code.

- **Checkpoint 8: Executable Test Cases in Docs**
    - [ ] Design a syntax for embedding executable test cases within doc comments (similar to Rust's `cargo test --doc`).
    - [ ] Modify `jaidoc_plugin` to extract these test cases.
    - [ ] Update `build.jai` or create a separate tool to run these documentation tests.
    - [ ] Add examples to `src/sample/sample.jai`.

- **Checkpoint 9: Sample App Expansion & Comprehensive Testing**
    - [ ] Systematically add more complex Jai features to `src/sample/sample.jai` (e.g., advanced struct usage, unions, modules, context-sensitive procedures, etc.).
    - [ ] Ensure `jaidoc` correctly documents all supported Jai constructs.

- **Checkpoint 10: Plugin System Investigation & Refinement**
    - [ ] Investigate how the Jai compiler's plugin system discovers and loads plugins.
    - [ ] If necessary, refactor the `jaidoc_plugin` directory structure or build process for better integration or distribution.

- **Checkpoint 11: Final Review, Polish, and Documentation for `jaidoc` itself**
    - [ ] Review all features.
    - [ ] Polish UI/UX of generated docs.
    - [ ] Write documentation for `jaidoc` (how to use it, how to build it, etc.).
