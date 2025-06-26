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

    // Generate HTML for each section
    if procedures.count > 0 {
        header_item: Nav_Item; 
        header_item.kind = .HEADER;
        header_item.text = "PROCEDURES";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">");
        array_add(lines, "            <h3 id=\"procedures\">Procedures</h3>");
        for decl: procedures {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("procedure_%_%", decl.name, decl.line_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4><a href=\"#\" class=\"source-link\">Source</a></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.type_string));
        }
        array_add(lines, "        </div>");
    }

    if structs.count > 0 {
        header_item: Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "STRUCTS";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">");
        array_add(lines, "            <h3 id=\"structs\">Structs</h3>");
        for decl: structs {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("struct_%_%", decl.name, decl.line_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4><a href=\"#\" class=\"source-link\">Source</a></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.type_string));
        }
        array_add(lines, "        </div>");
    }
    
    if enums.count > 0 {
        header_item: Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "ENUMS";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">\n");
        array_add(lines, "            <h3 id=\"enums\">Enums</h3>");
        for decl: enums {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("enum_%_%", decl.name, decl.line_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4><a href=\"#\" class=\"source-link\">Source</a></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.type_string));
        }
        array_add(lines, "        </div>");
    }
    
    if unions.count > 0 {
        header_item: Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "UNIONS";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">");
        array_add(lines, "            <h3 id=\"unions\">Unions</h3>");
        for decl: unions {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("union_%_%", decl.name, decl.line_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4><a href=\"#\" class=\"source-link\">Source</a></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.type_string));
        }
        array_add(lines, "        </div>");
    }
    
    if type_aliases.count > 0 {
        header_item: Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "TYPE ALIASES";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">\n");
        array_add(lines, "            <h3 id=\"type-aliases\">Type Aliases</h3>\n");
        for decl: type_aliases {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("type_alias_%_%", decl.name, decl.line_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4><a href=\"#\" class=\"source-link\">Source</a></div>\n", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>\n", decl.type_string));
        }
        array_add(lines, "        </div>\n");
    }
    
    if constants.count > 0 {
        header_item: Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "CONSTANTS";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">\n");
        array_add(lines, "            <h3 id=\"constants\">Constants</h3>\n");
        for decl: constants {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("constant_%_%", decl.name, decl.line_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4><a href=\"#\" class=\"source-link\">Source</a></div>\n", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>\n", decl.type_string));
        }
        array_add(lines, "        </div>\n");
    }
    
    if variables.count > 0 {
        header_item: Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "GLOBAL VARIABLES";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">\n");
        array_add(lines, "            <h3 id=\"variables\">Global Variables</h3>\n");
        for decl: variables {
            link_item: Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("variable_%_%", decl.name, decl.line_number);
            link_item.text = decl.name;
            link_item.icon_path = get_icon_path(decl.kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4><a href=\"#\" class=\"source-link\">Source</a></div>\n", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>\n", decl.type_string));
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
    margin-top: 0;
    color: #888;
    font-size: 0.9em;
    letter-spacing: 1px;
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
