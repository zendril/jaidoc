// jaidoc_processor.jai - Main documentation processing entry point
// Now properly modularized with separate files for different functionality

#import "Compiler";
#import "Basic";
#import "File";
String :: #import "String";

// Import all jaidoc modules
JaidocTypes :: #import "jaidoc_types";
JaidocUtils :: #import "jaidoc_utils";
JaidocCode :: #import "jaidoc_code";
JaidocModel :: #import "jaidoc_model";
JaidocHTML :: #import "jaidoc_html";

// Re-export key functions and types for easier access
Jaidoc_Options :: JaidocTypes.Jaidoc_Options;
LogLevel :: JaidocTypes.LogLevel;
Declaration_Info :: JaidocTypes.Declaration_Info;

// Cache for file contents to avoid reading the same file multiple times
file_content_cache: Table(string, string);

extract_source_code :: (file_path: string, start_line: int, end_line: int, start_col: int, end_col: int) -> string {
    // Check if we already have this file in cache
    found, file_content := table_find_new(*file_content_cache, file_path);
    
    if !found {
        // Read the entire file
        content, success := read_entire_file(file_path);
        if !success {
            return "";
        }
        
        // Cache the file content
        table_add(*file_content_cache, copy_string(file_path), copy_string(content));
        file_content = content;
    }
    
    // Split content into lines
    lines: [..] string;
    current_line_builder: String_Builder;
    
    for i: 0..file_content.count-1 {
        if file_content[i] == #char "\n" {
            line_str := String.builder_to_string(*current_line_builder);
            array_add(*lines, line_str);
            String.reset(*current_line_builder);
        } else if file_content[i] != #char "\r" {
            String.append(*current_line_builder, file_content[i]);
        }
    }
    
    // Add the last line if it doesn't end with newline
    current_str := String.builder_to_string(*current_line_builder);
    if current_str.count > 0 {
        array_add(*lines, current_str);
    }
    
    // Build the source code string using character-precise locations
    builder: String_Builder;
    start_idx := start_line - 1;
    end_idx := end_line - 1;

    if start_idx < 0 || start_idx >= lines.count || end_idx < 0 || end_idx >= lines.count {
        return ""; // Invalid line numbers
    }

    if start_idx == end_idx {
        // Single-line declaration
        line := lines[start_idx];
        
        // Jai columns are 1-based and inclusive.
        s_col := start_col - 1;
        e_col := end_col - 1;

        if s_col >= 0 && s_col < line.count && e_col >= s_col && e_col < line.count {
            slice: string;
            slice.data = line.data + s_col;
            slice.count = e_col - s_col + 1;
            String.append(*builder, slice);
        } else {
            // Fallback to the whole line if column info is weird
            String.append(*builder, line);
        }
    } else {
        // Multi-line declaration

        // First line: from start_col to the end
        first_line := lines[start_idx];
        s_col := start_col - 1;
        if s_col >= 0 && s_col < first_line.count {
            slice: string;
            slice.data = first_line.data + s_col;
            slice.count = first_line.count - s_col;
            String.append(*builder, slice);
        } else {
            String.append(*builder, first_line);
        }
        String.append(*builder, "\n");

        // Middle lines: append them completely
        for i: start_idx + 1..end_idx - 1 {
            String.append(*builder, lines[i]);
            String.append(*builder, "\n");
        }

        // Last line: from the beginning to end_col (inclusive)
        last_line := lines[end_idx];
        e_col := end_col - 1;
        if e_col >= 0 && e_col < last_line.count {
            slice: string;
            slice.data = last_line.data;
            slice.count = e_col + 1;
            String.append(*builder, slice);
        } else {
            String.append(*builder, last_line);
        }
    }

    return String.builder_to_string(*builder);
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

debug_print :: (options: Jaidoc_Options, fmt: string, args: ..Any, indent_spaces := 0) {
    if options.log_level == .VERBOSE {
        temp_string := tprint(fmt, ..args);
        
        if indent_spaces > 0 {
            // Generate the indent string
            indent_string: string;
            indent_string.data = alloc(indent_spaces);
            indent_string.count = indent_spaces;
            memset(indent_string.data, #char " ", indent_spaces);
            defer free(indent_string.data);
            
            lines := String.split(temp_string, "\n");
            indented_lines: [..] string;
            
            for line: lines {
                if line.count > 0 {
                    indented_line := tprint("%1%2", indent_string, line);
                    array_add(*indented_lines, indented_line);
                } else {
                    // Don't add indentation to empty lines
                    array_add(*indented_lines, line);
                }
            }
            
            final_string := String.join(..indented_lines, separator = "\n");
            print("%", final_string);
        } else {
            print("%", temp_string);
        }
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

Nav_Item_Kind :: enum {
    HEADER;
    LINK;
}

Nav_Item :: struct {
    kind: Nav_Item_Kind;
    text: string;
    id: string;
    icon_path: string;
}

get_icon_path :: (kind: Declaration_Kind) -> string {
    if kind == {
        case .PROCEDURE; return "assets/icons/procedure.svg";
        case .STRUCT; return "assets/icons/struct.svg";
        case .ENUM; return "assets/icons/enum.svg";
        case .UNION; return "assets/icons/union.svg";
        case .CONSTANT; return "assets/icons/constant.svg";
        case .VARIABLE; return "assets/icons/global_variable.svg";
        case .TYPE_ALIAS; return "assets/icons/global_variable.svg"; // Placeholder for now
    }
    return ""; // Default empty string
}

Declaration_Info :: struct {
    name: string;
    declaration_kind: Declaration_Kind;
    expression_kind: Code_Node.Kind;
    file_path: string;
    declaration_line_start_number: int;
    declaration_column_start_number: int;
    declaration_line_end_number: int;
    declaration_column_end_number: int;
    procedure_line_start_number: int;
    procedure_column_start_number: int;
    procedure_line_end_number: int;
    procedure_column_end_number: int;
    is_public: bool;
    source_code: string;  // The actual source code for this declaration
    declaration_code: string; // The actual declaration code for this declaration
    
    parameters: [..]string;
    return_type: string;
    members: [..]string;
    initial_value: string;
    code_declaration: *Code_Declaration;
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

process_declaration :: (decl_info: *Declaration_Info, options: Jaidoc_Options) {
    if decl_info.code_declaration.expression {
        expr := decl_info.code_declaration.expression;
        code_declaration := decl_info.code_declaration;
        decl_info.expression_kind = expr.kind;
        decl_info.declaration_kind = get_declaration_kind(expr);

        if expr.kind == {
            case .PROCEDURE_HEADER;
                proc_header := cast(*Code_Procedure_Header) expr;
                if proc_header.body_or_null {
                    body := proc_header.body_or_null;
                    debug_print(options, "Procedure % body kind: %\n", decl_info.name, body.kind, indent_spaces = 4);
                    debug_print(options, "Procedure % body location: l0=%, c0=%, l1=%, c1=%\n", decl_info.name, body.location.l0, body.location.c0, body.location.l1, body.location.c1, indent_spaces = 4);
                    
                    // Check if the body is a PROCEDURE_BODY (which should have a block)
                    if body.kind == .PROCEDURE_BODY {
                        proc_body := cast(*Code_Procedure_Body) body;
                        if proc_body.block {
                            block := proc_body.block;
                            debug_print(options, "Procedure % body block location: l0=%, c0=%, l1=%, c1=%\n", decl_info.name, block.location.l0, block.location.c0, block.location.l1, block.location.c1, indent_spaces = 4);
                            decl_info.procedure_line_end_number = block.location.l1;
                            decl_info.procedure_column_end_number = block.location.c1;
                        } else {
                            debug_print(options, "Procedure % body location: l0=%, c0=%, l1=%, c1=%\n", decl_info.name, body.location.l0, body.location.c0, body.location.l1, body.location.c1, indent_spaces = 4);
                            decl_info.procedure_line_end_number = body.location.l1;
                            decl_info.procedure_column_end_number = body.location.c1;
                        }
                    }
                }
                decl_info.source_code = copy_string(extract_source_code(decl_info.file_path, decl_info.procedure_line_start_number, decl_info.procedure_line_end_number, decl_info.procedure_column_start_number, decl_info.procedure_column_end_number));
                decl_info.declaration_code = copy_string(extract_source_code(decl_info.file_path, decl_info.declaration_line_start_number, decl_info.declaration_line_end_number, decl_info.declaration_column_start_number, decl_info.declaration_column_end_number));
            case .PROCEDURE_BODY;
                proc_body := cast(*Code_Procedure_Body) expr;
                // For procedure bodies, use the body's location directly
                decl_info.procedure_line_end_number = proc_body.location.l1;
                decl_info.procedure_column_end_number = proc_body.location.c1;
                debug_print(options, "Found PROCEDURE_BODY for '%' - extending to line %\n", decl_info.name, decl_info.procedure_line_end_number, indent_spaces = 4);
            case .STRUCT;
                struct_node := cast(*Code_Struct) expr;
                if struct_node.block {
                    block := struct_node.block;
                    // Extend end location to include the block
decl_info.procedure_line_end_number = block.location.l1;
                    decl_info.procedure_column_end_number = block.location.c1;
                }
                decl_info.source_code = copy_string(extract_source_code(decl_info.file_path, decl_info.procedure_line_start_number, decl_info.procedure_line_end_number, decl_info.procedure_column_start_number, decl_info.procedure_column_end_number));
                decl_info.declaration_code = copy_string(extract_source_code(decl_info.file_path, decl_info.procedure_line_start_number, decl_info.procedure_line_end_number, decl_info.procedure_column_start_number, decl_info.procedure_column_end_number));
            case .ENUM;
                enum_node := cast(*Code_Enum) expr;
                if enum_node.block {
                    block := enum_node.block;
                    // Extend end location to include the block
decl_info.procedure_line_end_number = block.location.l1;
                    decl_info.procedure_column_end_number = block.location.c1;
                }
                decl_info.source_code = copy_string(extract_source_code(decl_info.file_path, decl_info.procedure_line_start_number, decl_info.procedure_line_end_number, decl_info.procedure_column_start_number, decl_info.procedure_column_end_number));
                decl_info.declaration_code = copy_string(extract_source_code(decl_info.file_path, decl_info.procedure_line_start_number, decl_info.procedure_line_end_number, decl_info.procedure_column_start_number, decl_info.procedure_column_end_number));
            case .LITERAL;
                if code_declaration.flags & .IS_CONSTANT != 0 {
                    decl_info.declaration_kind = .CONSTANT;
                    // decl_info.type_string = copy_string("constant");
                } else {
                    decl_info.declaration_kind = .VARIABLE;
                    // decl_info.type_string = copy_string("variable");
                }
                decl_info.source_code = copy_string(extract_source_code(decl_info.file_path, decl_info.procedure_line_start_number, decl_info.procedure_line_end_number, decl_info.procedure_column_start_number, decl_info.procedure_column_end_number));
                decl_info.declaration_code = copy_string(extract_source_code(decl_info.file_path, decl_info.procedure_line_start_number, decl_info.procedure_line_end_number, decl_info.procedure_column_start_number, decl_info.procedure_column_end_number));
            case;
                debug_print(options, "Unhandled expression kind for '%': %\n", decl_info.name, expr.kind);
        }
    } else {
        debug_print(options, "No expression for declaration '%': %\n", decl_info.name);
    }
    debug_print(options, "Declaration Info: %\n", decl_info.*, indent_spaces = 4);
}

process_message :: (message: *Message, options: Jaidoc_Options) {
    num_messages += 1;
    if message.kind == {
      case .PHASE;
        mp := cast(*Message_Phase) message;
        debug_print(options, "\nPHASE: %\n", mp.phase);
        
      case .FILE;
        mf := cast(*Message_File) message;

        if mf.enclosing_import != null && mf.enclosing_import.module_type == .MAIN_PROGRAM {
            debug_print(options, "\nFILE:\n", indent_spaces = 2);
            debug_print(options, "Local main filename: %\n", mf.fully_pathed_filename, indent_spaces = 4);
            debug_print(options, "with enclosing_import.module_name: %\n", ifx mf.enclosing_import.module_name == "" "none" else mf.enclosing_import.module_name, indent_spaces = 6);
            array_add(*target_files, copy_string(mf.fully_pathed_filename));
            
            // Create file info for main program files
            find_or_create_file_info(mf.fully_pathed_filename, "");
        }

        if mf.enclosing_import != null && mf.enclosing_import.module_type == .FILE {
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
                debug_print(options, "\nFILE:\n", indent_spaces = 2);
                debug_print(options, "Local module file: %\n", filename, indent_spaces = 4);
                
                // Extract module name from the import
                if mf.enclosing_import && mf.enclosing_import.module_name {
                    module_name := mf.enclosing_import.module_name;
                    debug_print(options, "Module name: %\n", module_name, indent_spaces = 6);
                    
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
                debug_print(options, "\nTYPECHECKED:\n", indent_spaces = 2);
                debug_print(options, "Local filename: %\n", filename, indent_spaces = 4);

                declname := code_declaration.entry.name;

                // Create declaration info and add to data model
                decl_info: Declaration_Info;
                
                decl_info.name = copy_string(declname);
                decl_info.file_path = copy_string(filename);
                decl_info.declaration_line_start_number = code_declaration.location.l0;
                decl_info.declaration_line_end_number = code_declaration.location.l1;
                decl_info.declaration_column_start_number = code_declaration.location.c0;
                decl_info.declaration_column_end_number = code_declaration.location.c1;
                decl_info.procedure_line_start_number = code_declaration.location.l0;
                decl_info.procedure_line_end_number = code_declaration.location.l1;
                decl_info.procedure_column_start_number = code_declaration.location.c0;
                decl_info.procedure_column_end_number = code_declaration.location.c1;
                decl_info.is_public = is_declaration_public(code_declaration);
                decl_info.code_declaration = code_declaration;
                
                // Add declaration to the appropriate file
                file_info := find_or_create_file_info(filename);
                array_add(*file_info.declarations, decl_info);
            }
        }
        
      case .COMPLETE;
        debug_print(options, "COMPLETE.\n");

        // let's loop through all of the declarations in both main files and modules and write the declaration name and the body_or_null value
        for file_info: doc_model.main_files {
            for *decl_info: file_info.declarations {
                process_declaration(decl_info, options);
            }
        }

        
        for module_info: doc_model.modules {
            for file_info: module_info.files {
                for *decl_info: file_info.declarations {
                    process_declaration(decl_info, options);
                }
            }
        }   
        print_documentation_summary(options);
    }
}

print_documentation_summary :: (options: Jaidoc_Options) {
    if options.log_level == .QUIET return;

    print("\n=== Documentation Summary ===\n");
    print("Main files: %\n", doc_model.main_files.count);
    
    total_main_declarations := 0;
    for file_info: doc_model.main_files {
        total_main_declarations += file_info.declarations.count;
    }
    print("Total declarations in main files: %\n", total_main_declarations);
    
    print("Modules: %\n", doc_model.modules.count);
    
    total_module_declarations := 0;
    for module_info: doc_model.modules {
        for file_info: module_info.files {
            total_module_declarations += file_info.declarations.count;
        }
    }
    print("Total declarations in modules: %\n", total_module_declarations);
    
    print("Total declarations: %\n", total_main_declarations + total_module_declarations);
    print("=============================\n");
}

generate_html_page :: (title: string, body_html: string, nav_links: [] Nav_Item, module_links: [] string, main_files: [] File_Info) -> string {
    builder: String_Builder;
    
    String.append(*builder, "<!DOCTYPE html>\n");
    String.append(*builder, "<html lang=\"en\">\n");
    String.append(*builder, "<head>\n");
    String.append(*builder, "    <meta charset=\"UTF-8\">\n");
    String.append(*builder, "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n");
    String.append(*builder, tprint("    <title>%</title>\n", title));
    String.append(*builder, "    <link rel=\"stylesheet\" href=\"css/main.css\">\n");
    String.append(*builder, "    <script>\n");
    String.append(*builder, "        function toggleSource(id) {\n");
    String.append(*builder, "            var element = document.getElementById(id);\n");
    String.append(*builder, "            element.classList.toggle('hidden');\n");
    String.append(*builder, "        }\n");
    String.append(*builder, "    </script>\n");
    String.append(*builder, "</head>\n");
    String.append(*builder, "<body>\n");
    
    // Left Sidebar
    String.append(*builder, "    <div class=\"left-sidebar\">\n");
    String.append(*builder, "        <h2>Jaidoc</h2>\n");
    String.append(*builder, "        <div class=\"search-bar\">\n");
    String.append(*builder, "            <input type=\"text\" placeholder=\"Search\">\n");
    String.append(*builder, "        </div>\n");
    String.append(*builder, "        <h3>MAIN FILES</h3>\n");
    String.append(*builder, "        <ul>\n");
    for file_info: main_files {
        file_html_name := "file_main.html";
        file_name := get_filename_from_path(file_info.path);
        String.append(*builder, tprint("            <li><a href=\"%\">%</a></li>\n", file_html_name, file_name));
    }
    String.append(*builder, "        </ul>\n");
    String.append(*builder, "        <h3>MODULES</h3>\n");
    String.append(*builder, "        <ul>\n");
    for link: module_links {
        link_href := sprint("module_%.html", link);
        String.append(*builder, tprint("            <li><a href=\"%\">%</a></li>\n", link_href, link));
    }
    String.append(*builder, "        </ul>\n");
    String.append(*builder, "    </div>\n");
    
    // Main Content
    String.append(*builder, "    <div class=\"main-content\">\n");
    String.append(*builder, body_html);
    String.append(*builder, "    </div>\n");
    
    // Right Navigation
    if nav_links.count > 0 {
        String.append(*builder, "    <div class=\"right-nav\">\n");
        String.append(*builder, "        <h3>On this page</h3>\n");
        String.append(*builder, "        <ul>\n");
        for item: nav_links {
            if item.kind == .HEADER {
                String.append(*builder, tprint("            <h3 class=\"nav-section-header\">%</h3>\n", item.text));
            } else if item.kind == .LINK {
                String.append(*builder, tprint("            <li><a href=\"#%\"><img src=\"../%\" alt=\"% Icon\" class=\"icon\">%</a></li>\n", item.id, item.icon_path, item.text, item.text));
            }
        }
        String.append(*builder, "        </ul>\n");
    }
    
    String.append(*builder, "</body>\n");
    String.append(*builder, "</html>\n");
    
    return builder_to_string(*builder);
}

generate_declarations_html :: (declarations: [] Declaration_Info, lines: *[..] string) -> [..]Nav_Item {
    nav_links: [..]Nav_Item;
    
    if declarations.count == 0 {
        array_add(lines, "        <p>No declarations found in this file.</p>");
        return nav_links;
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
        if decl.declaration_kind == {
            case .PROCEDURE; array_add(*procedures, decl);
            case .STRUCT; array_add(*structs, decl);
            case .ENUM; array_add(*enums, decl);
            case .CONSTANT; array_add(*constants, decl);
            case .VARIABLE; array_add(*variables, decl);
            case .UNION; array_add(*unions, decl);
            case .TYPE_ALIAS; array_add(*type_aliases, decl);
        }
    }

    // Generate HTML for each section
    if procedures.count > 0 {
        header_item: Nav_Item; 
        header_item.kind = .HEADER;
        header_item.text = "PROCEDURES";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">");
        array_add(lines, "            <h3 id=\"procedures\"><img src=\"assets/icons/procedure.svg\" alt=\"\" class=\"section-icon\">Procedures</h3>");
        for decl: procedures {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("procedure_%_%", decl.name, decl.procedure_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4><a href=\"javascript:void(0);\" class=\"source-link\" onclick=\"toggleSource('%s_source')\">Source</a></div>", link_item.id, decl.name, link_item.id));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
            array_add(lines, tprint("            <div id=\"%s_source\" class=\"code-block hidden\"><pre><code>%</code></pre></div>", link_item.id, decl.source_code));
        }
        array_add(lines, "        </div>");
    }

    if structs.count > 0 {
        header_item: Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "STRUCTS";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">");
        array_add(lines, "            <h3 id=\"structs\"><img src=\"assets/icons/struct.svg\" alt=\"\" class=\"section-icon\">Structs</h3>");
        for decl: structs {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("struct_%_%", decl.name, decl.declaration_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
        }
        array_add(lines, "        </div>");
    }
    
    if enums.count > 0 {
        header_item: Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "ENUMS";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">\n");
        array_add(lines, "            <h3 id=\"enums\"><img src=\"assets/icons/enum.svg\" alt=\"\" class=\"section-icon\">Enums</h3>");
        for decl: enums {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("enum_%_%", decl.name, decl.declaration_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
        }
        array_add(lines, "        </div>");
    }
    
    if unions.count > 0 {
        header_item: Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "UNIONS";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">");
        array_add(lines, "            <h3 id=\"unions\"><img src=\"assets/icons/union.svg\" alt=\"\" class=\"section-icon\">Unions</h3>");
        for decl: unions {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("union_%_%", decl.name, decl.declaration_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
        }
        array_add(lines, "        </div>");
    }
    
    if type_aliases.count > 0 {
        header_item: Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "TYPE ALIASES";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">\n");
        array_add(lines, "            <h3 id=\"type-aliases\"><img src=\"assets/icons/global_variable.svg\" alt=\"\" class=\"section-icon\">Type Aliases</h3>\n");
        for decl: type_aliases {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("type_alias_%_%", decl.name, decl.declaration_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
        }
        array_add(lines, "        </div>\n");
    }
    
    if constants.count > 0 {
        header_item: Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "CONSTANTS";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">\n");
        array_add(lines, "            <h3 id=\"constants\"><img src=\"assets/icons/constant.svg\" alt=\"\" class=\"section-icon\">Constants</h3>\n");
        for decl: constants {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("constant_%_%", decl.name, decl.declaration_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
        }
        array_add(lines, "        </div>\n");
    }
    
    if variables.count > 0 {
        header_item: Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "GLOBAL VARIABLES";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">\n");
        array_add(lines, "            <h3 id=\"variables\"><img src=\"assets/icons/global_variable.svg\" alt=\"\" class=\"section-icon\">Global Variables</h3>\n");
        for decl: variables {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("variable_%_%", decl.name, decl.declaration_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
        }
        array_add(lines, "        </div>\n");
    }
    
    return nav_links;
}

generate_html_docs :: (options: Jaidoc_Options) {
    // Create output directory
    if !File_Utilities.file_exists(options.output_directory) {
        make_directory_if_it_does_not_exist(options.output_directory, true);
        debug_print(options, "Created output directory: %\n", options.output_directory);
    }

    // Create CSS directory and file
    css_dir := sprint("%/css", options.output_directory);
    if !File_Utilities.file_exists(css_dir) {
        make_directory_if_it_does_not_exist(css_dir, true);
        debug_print(options, "Created CSS directory: %\n", css_dir);
    }
    
    // Generate CSS content
    css_content := #string END
/* General Body Styles */
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    line-height: 1.6;
    margin: 0;
    padding: 0;
    display: flex;
    background-color: #121212;
    color: #E0E0E0;
}

/* Left Sidebar Styles */
.left-sidebar {
    width: 240px;
    min-width: 240px;
    padding: 20px;
    background-color: #1A1A1A;
    height: 100vh;
    position: sticky;
    top: 0;
    overflow-y: auto;
}

.left-sidebar h2 {
    font-size: 1.5em;
    margin-bottom: 20px;
}

.search-bar input {
    width: 100%;
    padding: 8px;
    border-radius: 5px;
    border: 1px solid #333;
    background-color: #2C2C2C;
    color: #E0E0E0;
}

.nav-buttons {
    margin: 20px 0;
}

.nav-buttons button {
    width: 100%;
    padding: 10px;
    margin-bottom: 10px;
    border-radius: 5px;
    border: 1px solid #333;
    background-color: #2C2C2C;
    color: #E0E0E0;
    cursor: pointer;
}

.left-sidebar h3 {
    font-size: 0.9em;
    color: #888;
    margin-top: 20px;
    margin-bottom: 10px;
    letter-spacing: 1px;
}

.left-sidebar ul {
    list-style-type: none;
    padding: 0;
    margin: 0;
}

.left-sidebar li a {
    text-decoration: none;
    color: #E0E0E0;
    display: block;
    padding: 8px 10px;
    border-radius: 5px;
    transition: background-color 0.2s;
}

.left-sidebar li a:hover, .left-sidebar li a.active {
    background-color: #333;
}

/* Main Content Styles */
.main-content {
    flex-grow: 1;
    padding: 40px;
}

/* Right Navigation Styles */
.right-nav {
    width: 220px;
    min-width: 220px;
    padding: 20px;
    height: 100vh;
    position: sticky;
    top: 0;
    overflow-y: auto;
}

.right-nav h3 {
    margin-top: 40px;
    color: #888;
    font-size: 0.9em;
    letter-spacing: 1px;
}

.right-nav h3:first-child {
    margin-top: 0;
}

.right-nav ul {
    list-style-type: none;
    padding: 0;
    margin: 0;
}

.right-nav li a {
    text-decoration: none;
    color: #AAA;
    display: block;
    padding: 5px 0;
    border-radius: 3px;
    transition: color 0.2s;
}

.right-nav li a:hover {
    color: #E0E0E0;
}

/* Header Styles */
h1, h2, h3, h4, h5, h6 {
    scroll-margin-top: 20px;
    color: #E0E0E0;
}

h1 {
    font-size: 2.5em;
    padding-bottom: 10px;
    margin-bottom: 0;
}

h2 {
    font-size: 1.8em;
    border-bottom: 1px solid #333;
    padding-bottom: 5px;
}

.filepath {
    font-size: 0.9em;
    color: #888;
    margin-top: 0;
    margin-bottom: 0;
    padding-bottom: 0;
    border-bottom: none;
}

.module-import-path {
    font-size: 0.9em;
    color: #888;
    margin-top: 0;
    margin-bottom: 20px;
    border-bottom: 1px solid #333;
    padding-bottom: 10px;
}

/* Declaration Section Styles */
.declaration-section {
    margin-bottom: 40px;
}

.declaration-section h3 {
    color: #E0E0E0;
    margin-bottom: 20px;
    font-size: 1.5em;
    display: flex;
    align-items: center;
}

.section-icon {
    width: 20px;
    height: 20px;
    margin-right: 10px;
    vertical-align: middle;
}

.declaration-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 10px;
}

.declaration-header h4 {
    color: #E0E0E0;
    font-size: 1.2em;
    margin: 0;
}

.source-link {
    color: #888;
    font-size: 0.9em;
    text-decoration: none;
}

.source-link:hover {
    text-decoration: underline;
}

/* Code Block Styles */
.code-block {
    background-color: #1A1A1A;
    border: 1px solid #333;
    padding: 15px;
    border-radius: 5px;
    margin: 10px 0;
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, Courier, monospace;
    font-size: 0.9em;
    overflow-x: auto;
}

.code-block pre {
    margin: 0;
}

.hidden {
    display: none;
}

/* Link Styles */
a {
    color: #58A6FF;
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

/* Responsive Design */
@media (max-width: 1024px) {
    .right-nav {
        display: none;
    }
}

@media (max-width: 768px) {
    body {
        flex-direction: column;
    }
    
    .left-sidebar {
        width: 100%;
        height: auto;
        position: static;
    }
    
    .main-content {
        padding: 20px;
    }
}

/* Icon Styles for Right Nav */
.right-nav .icon {
    width: 16px; /* Adjust as needed */
    height: 16px; /* Adjust as needed */
    margin-right: 8px;
    vertical-align: middle;
}
END;
    
    css_file_path := sprint("%/main.css", css_dir);
    css_success := write_entire_file(css_file_path, css_content);
    if css_success {
        debug_print(options, "Generated CSS file at %\n", css_file_path);
    } else {
        debug_print(options, "Failed to create CSS file at %\n", css_file_path);
    }

    // Copy assets directory
    assets_source_path := "assets";
    assets_dest_path := sprint("%/assets", options.output_directory);
    File_Utilities.copy_directory(assets_source_path, assets_dest_path);
    debug_print(options, "Attempted to copy assets from % to %\n", assets_source_path, assets_dest_path);
    
    // Generate and write index.html file
    index_file_path := sprint("%/index.html", options.output_directory);
    
    // Build index content
    index_body_lines: [..] string;
    array_add(*index_body_lines, "        <h1>Jaidoc Documentation</h1>");
    array_add(*index_body_lines, "        <h2>Main Program Files</h2>");
    
    if doc_model.main_files.count == 0 {
        array_add(*index_body_lines, "        <p>No main program files found.</p>");
    } else {
        for file_info: doc_model.main_files {
            file_html_name := "file_main.html";
            link_line := sprint("        <p><a href=\"%\">%</a></p>", file_html_name, file_info.path);
            array_add(*index_body_lines, link_line);
        }
    }
    
    array_add(*index_body_lines, "        <h2>Modules</h2>");
    
    module_links: [..]string;
    if doc_model.modules.count == 0 {
        array_add(*index_body_lines, "        <p>No modules found.</p>");
    } else {
        for module_info: doc_model.modules {
            array_add(*module_links, module_info.name);
            link_line := sprint("        <p><a href=\"module_%.html\">%</a></p>", module_info.name, module_info.name);
            array_add(*index_body_lines, link_line);
        }
    }
    
    // Create index page
    index_body := String.join(..index_body_lines, "\n");
    index_nav_links: [..]Nav_Item; // No navigation for index page
    index_html := generate_html_page("Jaidoc Documentation", index_body, index_nav_links, module_links, doc_model.main_files);
    
    index_success := write_entire_file(index_file_path, index_html);
    if index_success {
        debug_print(options, "Generated index.html at %\n", index_file_path);
    } else {
        debug_print(options, "Failed to create index.html at %\n", index_file_path);
    }
    
    // Generate documentation for main files
    for file_info: doc_model.main_files {
        file_body_lines: [..] string;
        file_name := get_filename_from_path(file_info.path);
        relative_path := String.replace(file_info.path, options.project_root, "");
        file_header := sprint("        <h1>%</h1>\n        <p class=\"filepath\">%</p>", file_name, relative_path);
        array_add(*file_body_lines, file_header);
        array_add(*file_body_lines, "        <h2>Declarations</h2>");
        
        nav_links: [..]Nav_Item;
        if file_info.declarations.count == 0 {
            array_add(*file_body_lines, "        <p>No declarations found in this file.</p>");
        } else {
            nav_links = generate_declarations_html(file_info.declarations, *file_body_lines);
        }
        
        // Create HTML page
        file_body := String.join(..file_body_lines, "\n");
        file_title := sprint("File: %", file_info.path);
        file_html := generate_html_page(file_title, file_body, nav_links, module_links, doc_model.main_files);
        
        // Write to file
        file_output_path := sprint("%/file_main.html", options.output_directory);
        file_success := write_entire_file(file_output_path, file_html);
        if file_success {
            debug_print(options, "Generated file_main.html at %\n", file_output_path);
        } else {
            debug_print(options, "Failed to create file_main.html at %\n", file_output_path);
        }
    }

    // Generate documentation for modules  
    for module_info: doc_model.modules {
        module_body_lines: [..] string;
        
        module_header := sprint("        <h1>Module: %</h1>", module_info.name);
        import_path_line := sprint("        <p class=\"module-import-path\"><strong>Import Path:</strong> <code>%</code></p>", module_info.import_path);
        
        array_add(*module_body_lines, module_header);
        
        if module_info.files.count > 0 {
            relative_path := String.replace(module_info.files[0].path, options.project_root, "");
            array_add(*module_body_lines, tprint("        <p class=\"filepath\">%</p>", relative_path));
        }
        array_add(*module_body_lines, import_path_line);
        
        nav_links: [..]Nav_Item;
        for file_info: module_info.files {
            
            
            if file_info.declarations.count == 0 {
                array_add(*module_body_lines, "        <p>No declarations found in this file.</p>");
            } else {
                file_nav_links := generate_declarations_html(file_info.declarations, *module_body_lines);
                // Combine navigation links from all files in the module
                for link: file_nav_links {
                    array_add(*nav_links, link);
                }
            }
        }
        
        // Create HTML page
        module_body := String.join(..module_body_lines, "\n");
        module_title := sprint("Module: %", module_info.name);
        module_html := generate_html_page(module_title, module_body, nav_links, module_links, doc_model.main_files);
        
        // Write to file
        module_output_path := sprint("%/module_%.html", options.output_directory, module_info.name);
        module_success := write_entire_file(module_output_path, module_html);
        if module_success {
            debug_print(options, "Generated module_% successfully\n", module_info.name);
            debug_print(options, "  Path: %\n", module_output_path);
        } else {
            debug_print(options, "Failed to create module_%\n", module_info.name);
            debug_print(options, "  Path: %\n", module_output_path);
        }
    }
}

process_finish :: (options: Jaidoc_Options) {
    if options.log_level == .VERBOSE {
        print("JaidocProcessor finished, which saw % messages.\n", num_messages);
    }
    
    generate_html_docs(options);

    // Clean up
    array_free(target_files);
    
    // Free documentation model memory
    for *file_info: doc_model.main_files {
        for *decl: file_info.declarations {
            free(decl.name);
            free(decl.file_path);
            free(decl.source_code);
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
                free(decl.source_code);
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
