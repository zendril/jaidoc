# jaidoc

A simple, powerful documentation generator for Jai codebases.

`jaidoc` parses your source code and generates clean, easy-to-navigate documentation in Markdown format.

![jaidoc-demo](./docs/jaidoc-demo3.webp)

## Usage

You can use `jaidoc` in two primary ways: as a direct compiler plugin or integrated into your own metaprogram (e.g. `build.jai`).

### Method 1: As a Compiler Plugin

This is the quickest way to generate documentation for a single file. You can pass arguments to the plugin directly after the `+jaidoc` directive.

*   **Default (Summary Output):**
    ```bash
    jai your_main_file.jai +jaidoc
    ```

*   **Quiet Mode (No Summary):**
    ```bash
    jai your_main_file.jai +jaidoc -quiet
    ```

*   **Verbose Mode (Detailed Debug Output):**
    ```bash
    jai your_main_file.jai +jaidoc -verbose
    ```

### Method 2: Integrated with `build.jai`

For more control and to document a whole project, you can integrate `jaidoc` into your existing build script.

*   **Default (Summary Output):**
    ```bash
    jai build.jai - clean build
    ```

*   **Quiet Mode (No Summary):**
    ```bash
    jai build.jai - clean build -quiet
    ```

*   **Verbose Mode (Detailed Debug Output):**
    ```bash
    jai build.jai - clean build -verbose
    ```

## Integration

To add `jaidoc` to your own `build.jai` file, you need to import the `jaidoc_processor.jai` library and add the compiler intercept loop. 

Here is a template you can adapt for your own build script:

```jai
// 1. Import the jaidoc processor
JaidocProcessor :: #import, file "path/to/jaidoc_processor.jai";

// Inside your main build logic...
#run {
    // ... your existing build setup ...

    // 2. Get command-line arguments for jaidoc
    build_options_for_args := get_build_options();
    args := build_options_for_args.compile_time_command_line;

    // 3. Configure Jaidoc options and log level
    jaidoc_options: JaidocProcessor.Jaidoc_Options;
    jaidoc_options.project_root = #filepath; // Set to your project's root
    jaidoc_options.output_directory = "target/docs/"; // Or your preferred output path

    if array_find(args, "-quiet") {
        jaidoc_options.log_level = .QUIET;
    } else if array_find(args, "-verbose") {
        jaidoc_options.log_level = .VERBOSE;
    } else {
        jaidoc_options.log_level = .DEFAULT;
    }

    // 4. Add the compiler intercept loop
    compiler_begin_intercept(workspace_handle); // Use your workspace handle
    add_build_file("path/to/your_main_file.jai", workspace_handle);
    
    while true {
        message := compiler_wait_for_message();
        if !message break;

        JaidocProcessor.process_message(message, jaidoc_options);

        if message.kind == .COMPLETE break;
    }
    compiler_end_intercept(workspace_handle);

    // 5. Finalize documentation generation
    JaidocProcessor.process_finish(jaidoc_options);

    // ... rest of your build script ...
}
```

## Configuration

### Output Directory

By default, `jaidoc` generates documentation in the `target/docs/` directory relative to your project root. You can customize this by setting the `output_directory` field in the `Jaidoc_Options` struct during integration.

### Custom Title

To set the title in the upper left of the site to something custom instead of Jaidoc at the following param: `-title "My App Title"`

Examples:

- Plugin: `jai src/sample/sample.jai +jaidoc -verbose -title "My App Title"`
- Metaprogram: `jai build.jai -quiet - clean build -title "My App Title"`

## Tips

### Build Artifacts

It is strongly recommended to direct all build outputs (executables, documentation, intermediate files) into a `target/` directory. This keeps your main project directory clean and separates source code from generated files.

### Clean Command

Your build script should include a `clean` command that deletes the `target/` directory. This ensures you can easily start a fresh build without any old artifacts causing issues. The `build.jai` in this project provides a working example.

### Version Control

To prevent build artifacts from being committed to your repository, add the `target/` directory to your `.gitignore` file.

```
# .gitignore
target/
```

## Extra resources

You can see minimal versions of Jaidoc in action with these two repositories:

- (https://github.com/zendril/jaidoc-sample-plugin)
    Shows an application using it as a plugin
- (https://github.com/zendril/jaidoc-sample-metaprogram)
    Shows an application using it as a metaprogram

## Local Build/Usage

This repo has been setup so that if you are working on Jaidoc, it operates the same as if you were using Jaidoc as an end user. 
Both the metaprogram instructions above and the plugin instructions above will work for this repo as well.

To view the outputs, run a simple webserver against `target/docs`.
Ex:`python -m http.server 8080 -d target\docs\`