// jaidoc_processor.jai - Core documentation processing library





// Compiler :: #import "Compiler";
#import "Compiler";
#import "Basic";
#import "File";
File_Utilities :: #import "File_Utilities";
String :: #import "String";

get_filename_from_path :: (path: string) -> string {
    last_slash := -1;
    for i: 0..path.count-1 {
        if path[i] == #char "/" || path[i] == #char "\\" {
            last_slash = i;
        }
    }

    if last_slash == -1 {
        return path;
    }

    result := path;
    result.data += (last_slash + 1);
    result.count -= (last_slash + 1);
    return result;
}

path_strip_extension :: (path: string) -> string {
    last_dot_index := -1;
    // Find the last dot.
    for i: path.count-1..0 {
        if path[i] == #char "." {
            last_dot_index = i;
            break;
        }
        // Don't go past a path separator.
        if path[i] == #char "/" || path[i] == #char "\\" {
            break;
        }
    }

    if last_dot_index > 0 {
        result := path;
        result.count = last_dot_index;
        return result;
    }

    return path;
}

LogLevel :: enum {
    QUIET;
    DEFAULT;
    VERBOSE;
}

Jaidoc_Options :: struct {
    output_directory: string = "docs";
    project_root: string = "";  // Root directory of the project being documented
    log_level: LogLevel = .DEFAULT;
}

debug_print :: (options: Jaidoc_Options, fmt: string, args: ..Any) {
    if options.log_level == .VERBOSE {
        print(fmt, args);
    }
}

// Data model for documentation
Declaration_Kind :: enum {
    VARIABLE;
    PROCEDURE;
    STRUCT;
    ENUM;
    UNION;
    CONSTANT;
    TYPE_ALIAS;
}

Declaration_Info :: struct {
    name: string;
    kind: Declaration_Kind;
    file_path: string;
    line_number: int;
    column_number: int;
    is_public: bool;
    type_string: string;
    comment: string;
    
    parameters: [..]string;
    return_type: string;
    members: [..]string;
    initial_value: string;
}

File_Info :: struct {
    path: string;
    module_name: string;
    declarations: [..]Declaration_Info;
}

Module_Info :: struct {
    name: string;
    import_path: string;
    files: [..]File_Info;
}

Documentation_Model :: struct {
    modules: [..]Module_Info;
    main_files: [..]File_Info; // Files that are part of the main program
}

num_messages := 0;
target_files: [..]string;
doc_model: Documentation_Model;

// Helper functions for data model population
find_or_create_file_info :: (file_path: string, module_name: string = "") -> *File_Info {
    // Check main files first
    for *file_info: doc_model.main_files {
        if file_info.path == file_path {
            return file_info;
        }
    }
    
    // Check module files
    for *module_info: doc_model.modules {
        for *file_info: module_info.files {
            if file_info.path == file_path {
                return file_info;
            }
        }
    }
    
    // Create new file info
    new_file: File_Info;
    new_file.path = copy_string(file_path);
    new_file.module_name = copy_string(module_name);
    
    if module_name == "" {
        // Add to main files
        array_add(*doc_model.main_files, new_file);
        return *doc_model.main_files[doc_model.main_files.count - 1];
    } else {
        // Find or create module and add file there
        module_info := find_or_create_module_info(module_name);
        array_add(*module_info.files, new_file);
        return *module_info.files[module_info.files.count - 1];
    }
}

find_or_create_module_info :: (module_name: string) -> *Module_Info {
    for *module_info: doc_model.modules {
        if module_info.name == module_name {
            return module_info;
        }
    }
    
    // Create new module
    new_module: Module_Info;
    new_module.name = copy_string(module_name);
    new_module.import_path = copy_string(module_name); // For now, same as name
    array_add(*doc_model.modules, new_module);
    return *doc_model.modules[doc_model.modules.count - 1];
}

get_declaration_kind :: (expr: *Code_Node) -> Declaration_Kind {
    if !expr return .VARIABLE;
    
    // Now we can use the actual enum values we see in the debug output
    if expr.kind == {
        case .PROCEDURE_HEADER;
            return .PROCEDURE;
        case .STRUCT;
            cs := cast(*Code_Struct) expr;
            if cs.defined_type {
                ts := cast(*Type_Info_Struct) cs.defined_type;
                if ts.textual_flags & .UNION return .UNION;
            }
            return .STRUCT;
        case .ENUM;
            return .ENUM;
        case .LITERAL;
            return .CONSTANT;
        case;
            return .VARIABLE; // Default for other expressions
    }
}

is_declaration_public :: (decl: *Code_Declaration) -> bool {
    // In Jai, declarations are public by default unless marked with #scope_file
    // For now, we'll consider all declarations public unless we detect private markers
    // This is a simplified approach - more sophisticated analysis would be needed
    return true;
}

extract_type_info :: (expr: *Code_Node) -> string {
    if !expr return "";
    
    // Use the actual enum values we see in the debug output
    if expr.kind == {
        case .PROCEDURE_HEADER;
            return "procedure";
        case .STRUCT;
            cs := cast(*Code_Struct) expr;
            if cs.defined_type {
                ts := cast(*Type_Info_Struct) cs.defined_type;
                if ts.textual_flags & .UNION return "union";
            }
            return "struct";
        case .ENUM;
            return "enum";
        case .LITERAL;
            return "constant";
        case;
            return "variable";
    }
}

process_message :: (message: *Message, options: Jaidoc_Options) {
    num_messages += 1;
    if message.kind == {
      case .PHASE;
        mp := cast(*Message_Phase) message;
        debug_print(options, "Now in phase: %\n", mp.phase);
        
      case .FILE;
        mf := cast(*Message_File) message;
        if mf.enclosing_import != null && mf.enclosing_import.module_type == .MAIN_PROGRAM {
            debug_print(options, "Now in file (main program): %\n", mf.fully_pathed_filename);
            debug_print(options, "--- enclosing_import.module_name %\n", mf.enclosing_import.module_name);
            array_add(*target_files, copy_string(mf.fully_pathed_filename));
            
            // Create file info for main program files
            find_or_create_file_info(mf.fully_pathed_filename, "");
        }

        if mf.enclosing_import != null && mf.enclosing_import.module_type == .FILE {
            debug_print(options, "Now in file (file): %\n", mf.fully_pathed_filename);
            debug_print(options, "--- enclosing_import.module_name %\n", mf.enclosing_import.module_name);
            
            // Check if this is a local module (not standard library)
            // We consider it local if it's in a subdirectory of our project
            filename := mf.fully_pathed_filename;
            project_root := options.project_root; // Use the new project_root field
            
            // Check if filename starts with project_root (case-insensitive, handle path separators)
            is_local := false;
            if project_root.count > 0 && filename.count > project_root.count {
                // Simple check: compare the beginning of the paths
                match := true;
                for i: 0..project_root.count-1 {
                    char_file := filename[i];
                    char_root := project_root[i];
                    
                    // Handle path separator differences (/ vs \)
                    if char_file == #char "/" char_file = #char "\\";
                    if char_root == #char "/" char_root = #char "\\";
                    
                    // Case insensitive comparison
                    if char_file >= #char "A" && char_file <= #char "Z" char_file += 32; // to lowercase
                    if char_root >= #char "A" && char_root <= #char "Z" char_root += 32; // to lowercase
                    
                    if char_file != char_root {
                        match = false;
                        break;
                    }
                }
                is_local = match;
            }
            
            if is_local {
                debug_print(options, "Found local module file: %\n", filename);
                
                // Extract module name from the import
                if mf.enclosing_import && mf.enclosing_import.module_name {
                    module_name := mf.enclosing_import.module_name;
                    debug_print(options, "Module name: %\n", module_name);
                    
                    // Add to target files so declarations get processed
                    array_add(*target_files, copy_string(filename));
                    
                    // Create or find module info and add this file
                    find_or_create_file_info(filename, module_name);
                }
            }
        }
        // TODO support file_message.from_a_string

      case .TYPECHECKED;
        tc := cast(*Message_Typechecked) message;
        
        for typechecked: tc.declarations {
            // code_declaration is Compiler.Code_Node
            code_declaration := typechecked.expression;

            filename := code_declaration.location.enclosing_load.fully_pathed_filename;
            if array_find(target_files, filename) {
                debug_print(options, "File: %\n", filename);

                declname := code_declaration.entry.name;
                debug_print(options, "Declaration: %\n", declname);

                // Create declaration info and add to data model
                decl_info: Declaration_Info;
                
                decl_info.name = copy_string(declname);
                decl_info.file_path = copy_string(filename);
                decl_info.line_number = code_declaration.location.l0;
                decl_info.column_number = code_declaration.location.c0;
                decl_info.is_public = is_declaration_public(code_declaration);
                
                if code_declaration.expression {
                    expr := code_declaration.expression;
                    if expr.kind == .LITERAL {
                        if code_declaration.flags & .IS_CONSTANT != 0 {
                            decl_info.kind = .CONSTANT;
                            decl_info.type_string = copy_string("constant");
                        } else {
                            decl_info.kind = .VARIABLE;
                            decl_info.type_string = copy_string("variable");
                        }
                    } else {
                        decl_info.kind = get_declaration_kind(expr);
                        decl_info.type_string = copy_string(extract_type_info(expr));
                        if decl_info.kind == .PROCEDURE {
                            decl_info.return_type = copy_string("void"); // Placeholder
                        }
                        // struct/enum members handled in KIND logic if needed
                    }
                } else {
                    decl_info.kind = .VARIABLE;
                    decl_info.type_string = copy_string("variable");
                }
                
                // Add declaration to the appropriate file
                file_info := find_or_create_file_info(filename);
                array_add(*file_info.declarations, decl_info);
                
                // Debug info removed to avoid format string issues
            }
        }
        
      case .COMPLETE;
        debug_print(options, "Got COMPLETE.\n");
        print_documentation_summary(options);
    }
}

print_documentation_summary :: (options: Jaidoc_Options) {
    if options.log_level == .QUIET return;

    print("\n=== Documentation Model Summary ===\n");
    
    print("Main Program Files: %\n", doc_model.main_files.count);
    for file_info: doc_model.main_files {
        print("  File: %\n", file_info.path);
        print("    Declarations: %\n", file_info.declarations.count);
        for decl: file_info.declarations {
            print("      - % (%) [%:%]\n", decl.name, decl.kind, decl.line_number, decl.column_number);
        }
    }
    
    print("Imported Modules: %\n", doc_model.modules.count);
    for module_info: doc_model.modules {
        print("  Module: %\n", module_info.name);
        print("    Files: %\n", module_info.files.count);
        for file_info: module_info.files {
            print("    File: %\n", file_info.path);
            print("      Declarations: %\n", file_info.declarations.count);
            for decl: file_info.declarations {
                print("        - % (%) [%:%]\n", decl.name, decl.kind, decl.line_number, decl.column_number);
            }
        }
    }
}

// Helper function to sanitize file paths for Markdown filenames
sanitize_path_for_markdown :: (path: string) -> string {
    result := path;
    // Simple character replacement using sprint
    result = sprint("%", result);
    // Replace problematic characters with underscores manually
    // This is a simplified approach
    return result;
}

// Helper function to generate markdown documentation for declarations
generate_declarations_markdown :: (declarations: [] Declaration_Info, lines: *[..] string) {
    if declarations.count == 0 {
        array_add(lines, "No declarations found in this file.");
        return;
    }
    
    // Group declarations by kind
    procedures: [..] Declaration_Info;
    structs: [..] Declaration_Info;
    enums: [..] Declaration_Info;
    constants: [..] Declaration_Info;
    variables: [..] Declaration_Info;
    unions: [..] Declaration_Info;
    type_aliases: [..] Declaration_Info;
    
    // Sort declarations into groups
    for decl: declarations {
        if decl.kind == {
            case .PROCEDURE; array_add(*procedures, decl);
            case .STRUCT; array_add(*structs, decl);
            case .ENUM; array_add(*enums, decl);
            case .CONSTANT; array_add(*constants, decl);
            case .VARIABLE; array_add(*variables, decl);
            case .UNION; array_add(*unions, decl);
            case .TYPE_ALIAS; array_add(*type_aliases, decl);
        }
    }
    
    // Generate sections for each declaration type that has declarations
    if procedures.count > 0 {
        array_add(lines, "### Procedures");
        array_add(lines, "");
        for decl: procedures {
            decl_header := sprint("#### %", decl.name);
            decl_type := sprint("- **Type**: %", decl.type_string);
            decl_location := sprint("- **Location**: Line %, Column %", decl.line_number, decl.column_number);
            decl_public := sprint("- **Public**: %", decl.is_public);
            
            array_add(lines, decl_header);
            array_add(lines, decl_type);
            array_add(lines, decl_location);
            array_add(lines, decl_public);
            array_add(lines, "");
        }
    }
    
    if structs.count > 0 {
        array_add(lines, "### Structs");
        array_add(lines, "");
        for decl: structs {
            decl_header := sprint("#### %", decl.name);
            decl_type := sprint("- **Type**: %", decl.type_string);
            decl_location := sprint("- **Location**: Line %, Column %", decl.line_number, decl.column_number);
            decl_public := sprint("- **Public**: %", decl.is_public);
            
            array_add(lines, decl_header);
            array_add(lines, decl_type);
            array_add(lines, decl_location);
            array_add(lines, decl_public);
            array_add(lines, "");
        }
    }
    
    if enums.count > 0 {
        array_add(lines, "### Enums");
        array_add(lines, "");
        for decl: enums {
            decl_header := sprint("#### %", decl.name);
            decl_type := sprint("- **Type**: %", decl.type_string);
            decl_location := sprint("- **Location**: Line %, Column %", decl.line_number, decl.column_number);
            decl_public := sprint("- **Public**: %", decl.is_public);
            
            array_add(lines, decl_header);
            array_add(lines, decl_type);
            array_add(lines, decl_location);
            array_add(lines, decl_public);
            array_add(lines, "");
        }
    }
    
    if unions.count > 0 {
        array_add(lines, "### Unions");
        array_add(lines, "");
        for decl: unions {
            decl_header := sprint("#### %", decl.name);
            decl_type := sprint("- **Type**: %", decl.type_string);
            decl_location := sprint("- **Location**: Line %, Column %", decl.line_number, decl.column_number);
            decl_public := sprint("- **Public**: %", decl.is_public);
            
            array_add(lines, decl_header);
            array_add(lines, decl_type);
            array_add(lines, decl_location);
            array_add(lines, decl_public);
            array_add(lines, "");
        }
    }
    
    if type_aliases.count > 0 {
        array_add(lines, "### Type Aliases");
        array_add(lines, "");
        for decl: type_aliases {
            decl_header := sprint("#### %", decl.name);
            decl_type := sprint("- **Type**: %", decl.type_string);
            decl_location := sprint("- **Location**: Line %, Column %", decl.line_number, decl.column_number);
            decl_public := sprint("- **Public**: %", decl.is_public);
            
            array_add(lines, decl_header);
            array_add(lines, decl_type);
            array_add(lines, decl_location);
            array_add(lines, decl_public);
            array_add(lines, "");
        }
    }
    
    if constants.count > 0 {
        array_add(lines, "### Constants");
        array_add(lines, "");
        for decl: constants {
            decl_header := sprint("#### %", decl.name);
            decl_type := sprint("- **Type**: %", decl.type_string);
            decl_location := sprint("- **Location**: Line %, Column %", decl.line_number, decl.column_number);
            decl_public := sprint("- **Public**: %", decl.is_public);
            
            array_add(lines, decl_header);
            array_add(lines, decl_type);
            array_add(lines, decl_location);
            array_add(lines, decl_public);
            array_add(lines, "");
        }
    }
    
    if variables.count > 0 {
        array_add(lines, "### Variables");
        array_add(lines, "");
        for decl: variables {
            decl_header := sprint("#### %", decl.name);
            decl_type := sprint("- **Type**: %", decl.type_string);
            decl_location := sprint("- **Location**: Line %, Column %", decl.line_number, decl.column_number);
            decl_public := sprint("- **Public**: %", decl.is_public);
            
            array_add(lines, decl_header);
            array_add(lines, decl_type);
            array_add(lines, decl_location);
            array_add(lines, decl_public);
            array_add(lines, "");
        }
    }
}

// New function to generate markdown documentation
generate_markdown_docs :: (options: Jaidoc_Options) {
    // Create output directory
    if !File_Utilities.file_exists(options.output_directory) {
        make_directory_if_it_does_not_exist(options.output_directory, true);
        debug_print(options, "Created output directory: %\n", options.output_directory);
    }

    // Generate and write index.md file
    index_file_path := sprint("%/index.md", options.output_directory);
    
    // Build index content step by step
    index_lines: [..] string;
    array_add(*index_lines, "# Jaidoc Documentation");
    array_add(*index_lines, "");
    array_add(*index_lines, "## Main Program Files");
    array_add(*index_lines, "");
    
    if doc_model.main_files.count == 0 {
        array_add(*index_lines, "No main program files found.");
    } else {
        for file_info: doc_model.main_files {
            file_md_name := "file_main.md";
            link_line := sprint("- [%](%)", file_info.path, file_md_name);
            array_add(*index_lines, link_line);
        }
    }
    
    array_add(*index_lines, "");
    array_add(*index_lines, "## Modules");
    array_add(*index_lines, "");
    
    if doc_model.modules.count == 0 {
        array_add(*index_lines, "No modules found.");
    } else {
        for module_info: doc_model.modules {
            link_line := sprint("- [%](module_%.md)", module_info.name, module_info.name);
            array_add(*index_lines, link_line);
        }
    }
    
    // Join all lines with newlines
    index_content := String.join(..index_lines, "\n");
    index_content = sprint("%\n", index_content); // Add final newline
    
    success := write_entire_file(index_file_path, index_content);
    if success {
        debug_print(options, "Generated index.md at %\n", index_file_path);
    } else {
        debug_print(options, "Failed to create index.md at %\n", index_file_path);
    }
    
    // Generate simple documentation for main files
    for file_info: doc_model.main_files {
        file_lines: [..] string;
        file_header := sprint("# File: %", file_info.path);
        array_add(*file_lines, file_header);
        array_add(*file_lines, "");
        array_add(*file_lines, "## Declarations");
        array_add(*file_lines, "");
        
        if file_info.declarations.count == 0 {
            array_add(*file_lines, "No declarations found in this file.");
        } else {
            generate_declarations_markdown(file_info.declarations, *file_lines);
        }
        
        // Join all lines with newlines
        file_content := String.join(..file_lines, "\n");
        file_content = sprint("%\n", file_content); // Add final newline
        
        // Write to file
        file_output_path := sprint("%/file_main.md", options.output_directory);
        success := write_entire_file(file_output_path, file_content);
        if success {
            debug_print(options, "Generated file_main.md at %\n", file_output_path);
        } else {
            debug_print(options, "Failed to create file_main.md at %\n", file_output_path);
        }
    }

    // Generate simple documentation for modules  
    for module_info: doc_model.modules {
        module_lines: [..] string;
        
        module_header := sprint("# Module: %", module_info.name);
        import_path_line := sprint("Import Path: `%`", module_info.import_path);
        
        array_add(*module_lines, module_header);
        array_add(*module_lines, "");
        array_add(*module_lines, import_path_line);
        array_add(*module_lines, "");
        
        for file_info: module_info.files {
            file_header := sprint("## File: %", file_info.path);
            array_add(*module_lines, file_header);
            array_add(*module_lines, "");
            
            if file_info.declarations.count == 0 {
                array_add(*module_lines, "No declarations found in this file.");
            } else {
                generate_declarations_markdown(file_info.declarations, *module_lines);
            }
        }
        
        // Join all lines with newlines
        module_content := String.join(..module_lines, "\n");
        module_content = sprint("%\n", module_content); // Add final newline
        
        // Write to file
        module_output_path := sprint("%/module_%.md", options.output_directory, module_info.name);
        success := write_entire_file(module_output_path, module_content);
        if success {
            debug_print(options, "Generated module_% successfully\n", module_info.name);
            debug_print(options, "  Path: %\n", module_output_path);
        } else {
            debug_print(options, "Failed to create module_%\n", module_info.name);
            debug_print(options, "  Path: %\n", module_output_path);
        }
    }
}

generate_declarations_html :: (declarations: [] Declaration_Info, lines: *[..] string) {
    // Group declarations by kind
    variables: [..]Declaration_Info;
    procedures: [..]Declaration_Info;
    structs: [..]Declaration_Info;
    enums: [..]Declaration_Info;
    unions: [..]Declaration_Info;
    constants: [..]Declaration_Info;

    for decl: declarations {
        if !decl.is_public continue;
        if decl.kind == {
            case .VARIABLE;   array_add(*variables, decl);
            case .PROCEDURE;  array_add(*procedures, decl);
            case .STRUCT;     array_add(*structs, decl);
            case .ENUM;       array_add(*enums, decl);
            case .UNION;      array_add(*unions, decl);
            case .CONSTANT;   array_add(*constants, decl);
        }
    }

    // Generate HTML for each section
    if procedures.count > 0 {
        array_add(lines, "<div class=\"declaration-section\">");
        array_add(lines, "<h3>Procedures</h3>");
        for decl: procedures {
            // Simplified representation for now
            array_add(lines, tprint("<h4>%</h4>", decl.name));
            array_add(lines, tprint("<pre><code>%</code></pre>", decl.type_string));
        }
        array_add(lines, "</div>");
    }

    if structs.count > 0 {
        array_add(lines, "<div class=\"declaration-section\">");
        array_add(lines, "<h3>Structs</h3>");
        for decl: structs {
            array_add(lines, tprint("<h4>%</h4>", decl.name));
            array_add(lines, tprint("<pre><code>%</code></pre>", decl.type_string));
        }
        array_add(lines, "</div>");
    }
    
    if enums.count > 0 {
        array_add(lines, "<div class=\"declaration-section\">");
        array_add(lines, "<h3>Enums</h3>");
        for decl: enums {
            array_add(lines, tprint("<h4>%</h4>", decl.name));
            array_add(lines, tprint("<pre><code>%</code></pre>", decl.type_string));
        }
        array_add(lines, "</div>");
    }
    
    // ... Add other types as needed (unions, constants, etc.)
}


// New function to generate HTML documentation
generate_html_docs :: (options: Jaidoc_Options) {
    html_output_dir := String.join(options.output_directory, "/html", separator="");
    if !make_directory_if_it_does_not_exist(html_output_dir, true) {
        print("Error: Could not create HTML output directory: %\n", html_output_dir);
        return;
    }

    css_dir := String.join(html_output_dir, "/css", separator="");
    if !make_directory_if_it_does_not_exist(css_dir, true) {
        print("Error: Could not create CSS directory: %\n", css_dir);
        return;
    }

    css_content := #string END
/* General Body Styles */
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    line-height: 1.6;
    margin: 0;
    padding: 0;
    background-color: #121212;
    color: #e0e0e0;
    display: flex;
}

/* Sidebar Styles */
.sidebar {
    width: 250px;
    background-color: #1e1e1e;
    padding: 20px;
    height: 100vh;
    position: fixed;
    overflow-y: auto;
    border-right: 1px solid #333;
}

.sidebar h2 {
    color: #ffffff;
    margin-top: 0;
}

.sidebar ul {
    list-style-type: none;
    padding: 0;
}

.sidebar ul li a {
    color: #a0a0a0;
    text-decoration: none;
    display: block;
    padding: 8px 15px;
    border-radius: 4px;
    transition: background-color 0.3s, color 0.3s;
}

.sidebar ul li a:hover,
.sidebar ul li a.active {
    background-color: #333;
    color: #ffffff;
}

/* Main Content Styles */
.main-content {
    margin-left: 270px; /* Sidebar width + some padding */
    padding: 20px 40px;
    width: calc(100% - 270px);
}

h1, h2, h3 {
    color: #ffffff;
    border-bottom: 1px solid #333;
    padding-bottom: 10px;
}

pre {
    background-color: #1e1e1e;
    border: 1px solid #333;
    padding: 15px;
    border-radius: 5px;
    overflow-x: auto;
}

code {
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, Courier, monospace;
    background-color: #282828;
    padding: 2px 4px;
    border-radius: 3px;
}

pre code {
    background-color: transparent;
    padding: 0;
    border-radius: 0;
}

a {
    color: #4a90e2;
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

/* Declaration sections */
.declaration-section {
    margin-bottom: 30px;
}

.declaration-section h3 {
    margin-bottom: 15px;
}
END;
    css_path := String.join(css_dir, "/main.css", separator="");
    write_entire_file(css_path, css_content);

    // --- Generate sidebar and file pages ---
    sidebar_links: [..]string;

    // Process main files
    for file_info: doc_model.main_files {
        file_name_without_ext := path_strip_extension(get_filename_from_path(file_info.path));
        html_file_name := String.join(file_name_without_ext, ".html", separator="");
        array_add(*sidebar_links, String.join("<li><a href=\"", html_file_name, "\">", file_name_without_ext, "</a></li>", separator=""));

        // Generate content for this file's page
        page_lines: [..]string;
        array_add(*page_lines, String.join("<h1>", file_info.path, "</h1>", separator=""));
        generate_declarations_html(file_info.declarations, *page_lines);
        
        page_content := String.join(..page_lines, "\n");
        write_html_page(html_output_dir, html_file_name, "Main Files", page_content, sidebar_links);
    }

    // Process modules
    for module_info: doc_model.modules {
        html_file_name := String.join(module_info.name, ".html", separator="");
        array_add(*sidebar_links, String.join("<li><a href=\"", html_file_name, "\">", module_info.name, "</a></li>", separator=""));

        page_lines: [..]string;
        array_add(*page_lines, String.join("<h1>Module: ", module_info.name, "</h1>", separator=""));
        for file_info: module_info.files {
            array_add(*page_lines, String.join("<h2>File: ", file_info.path, "</h2>", separator=""));
            generate_declarations_html(file_info.declarations, *page_lines);
        }

        page_content := String.join(..page_lines, "\n");
        write_html_page(html_output_dir, html_file_name, module_info.name, page_content, sidebar_links);
    }

    // Write main index.html with populated sidebar
    index_content := get_html_page_wrapper("Welcome", "<header><h1>Welcome to Jaidoc</h1><p>Select a module or file from the sidebar to view its documentation.</p></header>", sidebar_links);
    index_path := String.join(html_output_dir, "/index.html", separator="");
    write_entire_file(index_path, index_content);


    if options.log_level != .QUIET {
        print("Generated HTML documentation in: %\n", html_output_dir);
    }
}

write_html_page :: (output_dir: string, file_name: string, title: string, content: string, sidebar_links: [] string) {
    page_wrapper := get_html_page_wrapper(title, content, sidebar_links);
    file_path := String.join(output_dir, "/", file_name, separator="");
    write_entire_file(file_path, page_wrapper);
}

get_html_page_wrapper :: (title: string, content: string, sidebar_links: [] string) -> string {
    sidebar_html := String.join(..sidebar_links, "\n");

    builder: String_Builder;
    append(*builder, "<!DOCTYPE html>\n");
    append(*builder, "<html lang=\"en\">\n");
    append(*builder, "<head>\n");
    append(*builder, "    <meta charset=\"UTF-8\">\n");
    append(*builder, "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n");
    append(*builder, String.join("    <title>", title, " - Jaidoc</title>\n", separator=""));
    append(*builder, "    <link rel=\"stylesheet\" href=\"css/main.css\">\n");
    append(*builder, "</head>\n");
    append(*builder, "<body>\n");
    append(*builder, "    <aside class=\"sidebar\">\n");
    append(*builder, "        <h2>Modules & Files</h2>\n");
    append(*builder, "        <nav>\n");
    append(*builder, "            <ul>\n");
    append(*builder, sidebar_html);
    append(*builder, "            </ul>\n");
    append(*builder, "        </nav>\n");
    append(*builder, "    </aside>\n");
    append(*builder, "    <main class=\"main-content\">\n");
    append(*builder, content);
    append(*builder, "    </main>\n");
    append(*builder, "</body>\n");
    append(*builder, "</html>\n");
    
    return builder_to_string(*builder);
}

process_finish :: (options: Jaidoc_Options) {
    if options.log_level == .VERBOSE {
        print("JaidocProcessor finished, which saw % messages.\n", num_messages);
    }
    
    generate_markdown_docs(options);
    generate_html_docs(options);

    // Clean up
    array_free(target_files);
    
    // Free documentation model memory
    for *file_info: doc_model.main_files {
        for *decl: file_info.declarations {
            free(decl.name);
            free(decl.file_path);
            free(decl.type_string);
            free(decl.comment);
            free(decl.return_type);
            free(decl.initial_value);
            array_free(decl.parameters);
            array_free(decl.members);
        }
        array_free(file_info.declarations);
        free(file_info.path);
        free(file_info.module_name);
    }
    array_free(doc_model.main_files);
    
    for *module_info: doc_model.modules {
        for *file_info: module_info.files {
            for *decl: file_info.declarations {
                free(decl.name);
                free(decl.file_path);
                free(decl.type_string);
                free(decl.comment);
                free(decl.return_type);
                free(decl.initial_value);
                array_free(decl.parameters);
                array_free(decl.members);
            }
            array_free(file_info.declarations);
            free(file_info.path);
            free(file_info.module_name);
        }
        array_free(module_info.files);
        free(module_info.name);
        free(module_info.import_path);
    }
    array_free(doc_model.modules);
}
