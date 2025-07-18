// jaidoc_html.jai - HTML generation functionality for jaidoc

#import "Basic";
#import "File";
File_Utilities :: #import "File_Utilities";
String :: #import "String";
JaidocTypes :: #import, file "jaidoc_types.jai";
JaidocUtils :: #import, file "jaidoc_utils.jai";
JaidocModel :: #import, file "jaidoc_model.jai";
JaidocCSS :: #import, file "jaidoc_css.jai";

// Helper function to build enhanced search index entries
build_enhanced_search_entry :: (url: string, title: string, page_type: string, content: string, declarations: [] JaidocTypes.Declaration_Info) -> string {
    builder: String_Builder;
    
    String.append(*builder, "{");
    String.append(*builder, tprint("\"url\":\"%\",", url));
    String.append(*builder, tprint("\"title\":\"%\",", title));
    String.append(*builder, tprint("\"type\":\"%\",", page_type));
    String.append(*builder, tprint("\"content\":\"%\",", content));
    String.append(*builder, "\"items\":[");
    
    if declarations.count > 0 {
        items: [..]string;
        for decl: declarations {
            item_builder: String_Builder;
            String.append(*item_builder, "{");
            
            // Generate unique ID for the declaration
            decl_id := tprint("%_%_%", get_declaration_type_string(decl.declaration_kind), decl.name, decl.declaration_line_start_number);
            String.append(*item_builder, tprint("\"id\":\"%\",", decl_id));
            String.append(*item_builder, tprint("\"name\":\"%\",", decl.name));
            String.append(*item_builder, tprint("\"type\":\"%\",", get_declaration_type_string(decl.declaration_kind)));
            
            // Create context snippet from declaration code (truncate if too long)
            context_text := decl.declaration_code;
            if context_text.count > 100 {
                context_text = tprint("%..", String.slice(context_text, 0, 97));
            }
            String.append(*item_builder, tprint("\"context\":\"%\",", escape_json_string(context_text)));
            String.append(*item_builder, tprint("\"anchor\":\"#%\"", decl_id));
            String.append(*item_builder, "}");
            
            array_add(*items, String.builder_to_string(*item_builder));
        }
        String.append(*builder, String.join(..items, ","));
    }
    
    String.append(*builder, "]}");
    return String.builder_to_string(*builder);
}

// Helper function to get declaration type as string
get_declaration_type_string :: (kind: JaidocTypes.Declaration_Kind) -> string {
    if kind == {
        case .PROCEDURE; return "procedure";
        case .STRUCT; return "struct";
        case .ENUM; return "enum";
        case .UNION; return "union";
        case .CONSTANT; return "constant";
        case .VARIABLE; return "variable";
        case .TYPE_ALIAS; return "type_alias";
    }
    return "unknown";
}

// Helper function to escape JSON strings
escape_json_string :: (input: string) -> string {
    builder: String_Builder;
    for i: 0..input.count-1 {
        char := input[i];
        if char == {
            case #char "\""; String.append(*builder, "\\\"");
            case #char "\\"; String.append(*builder, "\\\\");
            case #char "\n"; String.append(*builder, "\\n");
            case #char "\r"; String.append(*builder, "\\r");
            case #char "\t"; String.append(*builder, "\\t");
            case; String.append(*builder, char);
        }
    }
    return String.builder_to_string(*builder);
}

// Helper function to build content text for search indexing
build_content_text_for_file :: (file_info: JaidocTypes.File_Info) -> string {
    builder: String_Builder;
    
    // Add file name and path
    file_name := JaidocUtils.get_filename_from_path(file_info.path);
    String.append(*builder, file_name);
    String.append(*builder, " ");
    
    // Add section headers
    String.append(*builder, "Declarations ");
    
    // Add declaration names and types
    for decl: file_info.declarations {
        String.append(*builder, decl.name);
        String.append(*builder, " ");
        String.append(*builder, get_declaration_type_string(decl.declaration_kind));
        String.append(*builder, " ");
    }
    
    return String.builder_to_string(*builder);
}

// Helper function to build content text for modules
build_content_text_for_module :: (module_info: JaidocTypes.Module_Info) -> string {
    builder: String_Builder;
    
    // Add module name and import path
    String.append(*builder, module_info.name);
    String.append(*builder, " ");
    String.append(*builder, module_info.import_path);
    String.append(*builder, " ");
    
    // Add section headers
    String.append(*builder, "Module Procedures Structs Enums Unions Constants Variables ");
    
    // Add all declaration names from all files in the module
    for file_info: module_info.files {
        for decl: file_info.declarations {
            String.append(*builder, decl.name);
            String.append(*builder, " ");
            String.append(*builder, get_declaration_type_string(decl.declaration_kind));
            String.append(*builder, " ");
        }
    }
    
    return String.builder_to_string(*builder);
}

generate_html_page :: (title: string, body_html: string, nav_links: [] JaidocTypes.Nav_Item, module_links: [] string, main_files: [] JaidocTypes.File_Info) -> string {
    builder: String_Builder;
    
    String.append(*builder, "<!DOCTYPE html>\n");
    String.append(*builder, "<html lang=\"en\">\n");
    String.append(*builder, "<head>\n");
    String.append(*builder, "    <meta charset=\"UTF-8\">\n");
    String.append(*builder, "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n");
    String.append(*builder, tprint("    <title>%</title>\n", title));
    String.append(*builder, "    <link rel=\"stylesheet\" href=\"assets/css/main.css\">\n");
    // Include Fuse.js from local assets for client-side full-text search
    String.append(*builder, "    <script src=\"assets/js/fuse.min.js\"></script>\n");
    // Custom search logic shared by all pages (written to assets/js/search.js during generation)
    String.append(*builder, "    <script src=\"assets/js/search.js\"></script>\n");
    // Inline helpers (toggle source, etc.)
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
    String.append(*builder, "            <input id=\"search-input\" type=\"text\" placeholder=\"Search\">\n");
    // Container where search.js will inject results
    String.append(*builder, "            <div id=\"search-results\"></div>\n");
    String.append(*builder, "        </div>\n");
    String.append(*builder, "        <h3>MAIN FILES</h3>\n");
    String.append(*builder, "        <ul>\n");
    for file_info: main_files {
        file_html_name := "file_main.html";
        file_name := JaidocUtils.get_filename_from_path(file_info.path);
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
    
    return String.builder_to_string(*builder);
}

generate_declarations_html :: (declarations: [] JaidocTypes.Declaration_Info, lines: *[..] string) -> [..]JaidocTypes.Nav_Item {
    nav_links: [..]JaidocTypes.Nav_Item;
    
    if declarations.count == 0 {
        array_add(lines, "        <p>No declarations found in this file.</p>");
        return nav_links;
    }
    
    // Group declarations by kind
    procedures: [..] JaidocTypes.Declaration_Info;
    structs: [..] JaidocTypes.Declaration_Info;
    enums: [..] JaidocTypes.Declaration_Info;
    constants: [..] JaidocTypes.Declaration_Info;
    variables: [..] JaidocTypes.Declaration_Info;
    unions: [..] JaidocTypes.Declaration_Info;
    type_aliases: [..] JaidocTypes.Declaration_Info;
    
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
        header_item: JaidocTypes.Nav_Item; 
        header_item.kind = .HEADER;
        header_item.text = "PROCEDURES";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">");
        array_add(lines, "            <h3 id=\"procedures\"><img src=\"assets/icons/procedure.svg\" alt=\"\" class=\"section-icon\">Procedures</h3>");
        for decl: procedures {
            link_item: JaidocTypes.Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("procedure_%_%", decl.name, decl.procedure_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = JaidocUtils.get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4><a href=\"javascript:void(0);\" class=\"source-link\" onclick=\"toggleSource('%s_source')\">Source</a></div>", link_item.id, decl.name, link_item.id));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
            array_add(lines, tprint("            <div id=\"%s_source\" class=\"code-block hidden\"><pre><code>%</code></pre></div>", link_item.id, decl.source_code));
        }
        array_add(lines, "        </div>");
    }

    if structs.count > 0 {
        header_item: JaidocTypes.Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "STRUCTS";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">");
        array_add(lines, "            <h3 id=\"structs\"><img src=\"assets/icons/struct.svg\" alt=\"\" class=\"section-icon\">Structs</h3>");
        for decl: structs {
            link_item: JaidocTypes.Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("struct_%_%", decl.name, decl.declaration_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = JaidocUtils.get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
        }
        array_add(lines, "        </div>");
    }
    
    if enums.count > 0 {
        header_item: JaidocTypes.Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "ENUMS";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">\n");
        array_add(lines, "            <h3 id=\"enums\"><img src=\"assets/icons/enum.svg\" alt=\"\" class=\"section-icon\">Enums</h3>");
        for decl: enums {
            link_item: JaidocTypes.Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("enum_%_%", decl.name, decl.declaration_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = JaidocUtils.get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
        }
        array_add(lines, "        </div>");
    }
    
    if unions.count > 0 {
        header_item: JaidocTypes.Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "UNIONS";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">");
        array_add(lines, "            <h3 id=\"unions\"><img src=\"assets/icons/union.svg\" alt=\"\" class=\"section-icon\">Unions</h3>");
        for decl: unions {
            link_item: JaidocTypes.Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("union_%_%", decl.name, decl.declaration_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = JaidocUtils.get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
        }
        array_add(lines, "        </div>");
    }
    
    if type_aliases.count > 0 {
        header_item: JaidocTypes.Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "TYPE ALIASES";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">\n");
        array_add(lines, "            <h3 id=\"type-aliases\"><img src=\"assets/icons/global_variable.svg\" alt=\"\" class=\"section-icon\">Type Aliases</h3>\n");
        for decl: type_aliases {
            link_item: JaidocTypes.Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("type_alias_%_%", decl.name, decl.declaration_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = JaidocUtils.get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
        }
        array_add(lines, "        </div>\n");
    }
    
    if constants.count > 0 {
        header_item: JaidocTypes.Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "CONSTANTS";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">\n");
        array_add(lines, "            <h3 id=\"constants\"><img src=\"assets/icons/constant.svg\" alt=\"\" class=\"section-icon\">Constants</h3>\n");
        for decl: constants {
            link_item: JaidocTypes.Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("constant_%_%", decl.name, decl.declaration_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = JaidocUtils.get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
        }
        array_add(lines, "        </div>\n");
    }
    
    if variables.count > 0 {
        header_item: JaidocTypes.Nav_Item;
        header_item.kind = .HEADER;
        header_item.text = "GLOBAL VARIABLES";
        array_add(*nav_links, header_item);

        array_add(lines, "        <div class=\"declaration-section\">\n");
        array_add(lines, "            <h3 id=\"variables\"><img src=\"assets/icons/global_variable.svg\" alt=\"\" class=\"section-icon\">Global Variables</h3>\n");
        for decl: variables {
            link_item: JaidocTypes.Nav_Item;
            link_item.kind = .LINK;
            link_item.id = tprint("variable_%_%", decl.name, decl.declaration_line_start_number);
            link_item.text = decl.name;
            link_item.icon_path = JaidocUtils.get_icon_path(decl.declaration_kind);
            array_add(*nav_links, link_item);

            array_add(lines, tprint("            <div class=\"declaration-header\"><h4 id=\"%\">%</h4></div>", link_item.id, decl.name));
            array_add(lines, tprint("            <div class=\"code-block\"><pre><code>%</code></pre></div>", decl.declaration_code));
        }
        array_add(lines, "        </div>\n");
    }
    
    return nav_links;
}

generate_html_docs :: (options: JaidocTypes.Jaidoc_Options) {
    // Create output directory
    if !File_Utilities.file_exists(options.output_directory) {
        make_directory_if_it_does_not_exist(options.output_directory, true);
        JaidocUtils.debug_print(options, "Created output directory: %\n", options.output_directory);
    }

    // Generate CSS content and write to assets/css directory
    css_content := JaidocCSS.GET_CSS_CONTENT();
    
    // Ensure assets/css directory exists
    assets_css_dir := sprint("%/assets/css", options.output_directory);
    if !File_Utilities.file_exists(assets_css_dir) {
        make_directory_if_it_does_not_exist(assets_css_dir, true);
        JaidocUtils.debug_print(options, "Created assets/css directory: %\n", assets_css_dir);
    }
    
    css_file_path := sprint("%/assets/css/main.css", options.output_directory);
    css_success := write_entire_file(css_file_path, css_content);
    if css_success {
        JaidocUtils.debug_print(options, "Generated CSS file at %\n", css_file_path);
    } else {
        JaidocUtils.debug_print(options, "Failed to create CSS file at %\n", css_file_path);
    }

    // Copy assets directory
    jaidoc_module_dir := JaidocUtils.path_strip_filename(#filepath);
    assets_source_path := sprint("%/assets", jaidoc_module_dir);
    assets_dest_path := sprint("%/assets", options.output_directory);
    File_Utilities.copy_directory(assets_source_path, assets_dest_path);
    JaidocUtils.debug_print(options, "Attempted to copy assets from % to %\n", assets_source_path, assets_dest_path);
    
    // ---------------------------
    // Build search index entries
    // ---------------------------
    search_items: [..]string;
    // Add index page entry early
    empty_declarations: [..]JaidocTypes.Declaration_Info;
    index_entry := build_enhanced_search_entry("index.html", "Jaidoc Documentation", "page", "Jaidoc Documentation Main Program Files Modules", empty_declarations);
    array_add(*search_items, index_entry);

    // --------------------------------------------------
    // Generate and write index.html file
    index_file_path := sprint("%/index.html", options.output_directory);
    
    // Build index content
    index_body_lines: [..] string;
    array_add(*index_body_lines, "        <h1>Jaidoc Documentation</h1>");
    array_add(*index_body_lines, "        <h2>Main Program Files</h2>");
    
    if JaidocModel.doc_model.main_files.count == 0 {
        array_add(*index_body_lines, "        <p>No main program files found.</p>");
    } else {
        for file_info: JaidocModel.doc_model.main_files {
            file_html_name := "file_main.html";
            link_line := sprint("        <p><a href=\"%\">%</a></p>", file_html_name, file_info.path);
            array_add(*index_body_lines, link_line);
        }
    }
    
    array_add(*index_body_lines, "        <h2>Modules</h2>");
    
    module_links: [..]string;
    if JaidocModel.doc_model.modules.count == 0 {
        array_add(*index_body_lines, "        <p>No modules found.</p>");
    } else {
        for module_info: JaidocModel.doc_model.modules {
            array_add(*module_links, module_info.name);
            link_line := sprint("        <p><a href=\"module_%.html\">%</a></p>", module_info.name, module_info.name);
            array_add(*index_body_lines, link_line);
        }
    }
    
    // Create index page
    index_body := String.join(..index_body_lines, "\n");
    index_nav_links: [..]JaidocTypes.Nav_Item; // No navigation for index page
    index_html := generate_html_page("Jaidoc Documentation", index_body, index_nav_links, module_links, JaidocModel.doc_model.main_files);
    
    index_success := write_entire_file(index_file_path, index_html);
    if index_success {
        JaidocUtils.debug_print(options, "Generated index.html at %\n", index_file_path);
    } else {
        JaidocUtils.debug_print(options, "Failed to create index.html at %\n", index_file_path);
    }
    
    // Generate documentation for main files
    for file_info: JaidocModel.doc_model.main_files {
        file_body_lines: [..] string;
        file_name := JaidocUtils.get_filename_from_path(file_info.path);
        relative_path := String.replace(file_info.path, options.project_root, "");
        file_header := sprint("        <h1>%</h1>\n        <p class=\"filepath\">%</p>", file_name, relative_path);
        array_add(*file_body_lines, file_header);
        array_add(*file_body_lines, "        <h2>Declarations</h2>");
        
        nav_links: [..]JaidocTypes.Nav_Item;
        if file_info.declarations.count == 0 {
            array_add(*file_body_lines, "        <p>No declarations found in this file.</p>");
        } else {
            nav_links = generate_declarations_html(file_info.declarations, *file_body_lines);
        }
        
        // Create HTML page
        file_body := String.join(..file_body_lines, "\n");
        file_title := sprint("File: %", file_info.path);
        file_html := generate_html_page(file_title, file_body, nav_links, module_links, JaidocModel.doc_model.main_files);
        
        // Write to file
        file_output_path := sprint("%/file_main.html", options.output_directory);
        file_success := write_entire_file(file_output_path, file_html);
        // Add to search index with enhanced structure
        content_text := build_content_text_for_file(file_info);
        file_entry := build_enhanced_search_entry("file_main.html", file_title, "file", content_text, file_info.declarations);
        array_add(*search_items, file_entry);
        if file_success {
            JaidocUtils.debug_print(options, "Generated file_main.html at %\n", file_output_path);
        } else {
            JaidocUtils.debug_print(options, "Failed to create file_main.html at %\n", file_output_path);
        }
    }

    // Generate documentation for modules  
    for module_info: JaidocModel.doc_model.modules {
        module_body_lines: [..] string;
        
        module_header := sprint("        <h1>Module: %</h1>", module_info.name);
        import_path_line := sprint("        <p class=\"module-import-path\"><strong>Import Path:</strong> <code>%</code></p>", module_info.import_path);
        
        array_add(*module_body_lines, module_header);
        
        if module_info.files.count > 0 {
            relative_path := String.replace(module_info.files[0].path, options.project_root, "");
            array_add(*module_body_lines, tprint("        <p class=\"filepath\">%</p>", relative_path));
        }
        array_add(*module_body_lines, import_path_line);
        
        nav_links: [..]JaidocTypes.Nav_Item;
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
        module_html := generate_html_page(module_title, module_body, nav_links, module_links, JaidocModel.doc_model.main_files);
        // Add to search index with enhanced structure
        content_text := build_content_text_for_module(module_info);
        // Collect all declarations from all files in the module
        all_declarations: [..]JaidocTypes.Declaration_Info;
        for file_info: module_info.files {
            for decl: file_info.declarations {
                array_add(*all_declarations, decl);
            }
        }
        module_entry := build_enhanced_search_entry(sprint("module_%.html", module_info.name), module_title, "module", content_text, all_declarations);
        array_add(*search_items, module_entry);
        
        // Write to file
        module_output_path := sprint("%/module_%.html", options.output_directory, module_info.name);
        module_success := write_entire_file(module_output_path, module_html);
        if module_success {
            JaidocUtils.debug_print(options, "Generated module_% successfully\n", module_info.name);
            JaidocUtils.debug_print(options, "  Path: %\n", module_output_path);
        } else {
            JaidocUtils.debug_print(options, "Failed to create module_%\n", module_info.name);
            JaidocUtils.debug_print(options, "  Path: %\n", module_output_path);
        }
    }

    // -----------------------------
    // Write search-index.json file
    // -----------------------------
    search_json := String.join(..search_items, ",\n");
    search_json = sprint("[\n%\n]", search_json);
    search_index_path := sprint("%/search-index.json", options.output_directory);
    write_entire_file(search_index_path, search_json);

    // -----------------------------
    // Write search.js file (shared logic)
    // -----------------------------
    // Build enhanced search.js content with backward compatibility
    js_builder: String_Builder;
    String.append(*js_builder, "document.addEventListener('DOMContentLoaded', function() {\n");
    String.append(*js_builder, "  const input = document.getElementById('search-input');\n");
    String.append(*js_builder, "  if (!input) return;\n");
    String.append(*js_builder, "  fetch('search-index.json').then(r => r.json()).then(data => {\n");
    String.append(*js_builder, "    // Enhanced Fuse.js configuration for multi-field search\n");
    String.append(*js_builder, "    const fuseOptions = {\n");
    String.append(*js_builder, "      keys: [\n");
    String.append(*js_builder, "        { name: 'title', weight: 0.4 },\n");
    String.append(*js_builder, "        { name: 'content', weight: 0.2 },\n");
    String.append(*js_builder, "        { name: 'items.name', weight: 0.3 },\n");
    String.append(*js_builder, "        { name: 'items.context', weight: 0.1 }\n");
    String.append(*js_builder, "      ],\n");
    String.append(*js_builder, "      includeScore: true,\n");
    String.append(*js_builder, "      includeMatches: true,\n");
    String.append(*js_builder, "      threshold: 0.4,\n");
    String.append(*js_builder, "      minMatchCharLength: 2\n");
    String.append(*js_builder, "    };\n");
    String.append(*js_builder, "    const fuse = new Fuse(data, fuseOptions);\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    input.addEventListener('input', function() {\n");
    String.append(*js_builder, "      const query = this.value.trim();\n");
    String.append(*js_builder, "      const resultsDiv = document.getElementById('search-results');\n");
    String.append(*js_builder, "      if (!resultsDiv) return;\n");
    String.append(*js_builder, "      if (!query) { resultsDiv.innerHTML = ''; resultsDiv.classList.remove('show'); return; }\n");
    String.append(*js_builder, "      \n");
    String.append(*js_builder, "      const results = fuse.search(query, { limit: 20 });\n");
    String.append(*js_builder, "      \n");
    String.append(*js_builder, "      // Process results to handle both enhanced and legacy formats\n");
    String.append(*js_builder, "      const processedResults = [];\n");
    String.append(*js_builder, "      \n");
    String.append(*js_builder, "      results.forEach(function(result) {\n");
    String.append(*js_builder, "        const item = result.item;\n");
    String.append(*js_builder, "        \n");
    String.append(*js_builder, "        // Check if this is an enhanced format with items\n");
    String.append(*js_builder, "        if (item.items && item.items.length > 0) {\n");
    String.append(*js_builder, "          // Check if any matches are in the items array\n");
    String.append(*js_builder, "          let hasItemMatch = false;\n");
    String.append(*js_builder, "          if (result.matches) {\n");
    String.append(*js_builder, "            result.matches.forEach(function(match) {\n");
    String.append(*js_builder, "              if (match.key && match.key.startsWith('items.')) {\n");
    String.append(*js_builder, "                hasItemMatch = true;\n");
    String.append(*js_builder, "              }\n");
    String.append(*js_builder, "            });\n");
    String.append(*js_builder, "          }\n");
    String.append(*js_builder, "          \n");
    String.append(*js_builder, "          if (hasItemMatch) {\n");
    String.append(*js_builder, "            // Find the specific item that matched\n");
    String.append(*js_builder, "            item.items.forEach(function(subItem) {\n");
    String.append(*js_builder, "              if (subItem.name.toLowerCase().includes(query.toLowerCase()) || \n");
    String.append(*js_builder, "                  subItem.context.toLowerCase().includes(query.toLowerCase())) {\n");
    String.append(*js_builder, "                processedResults.push({\n");
    String.append(*js_builder, "                  url: item.url + subItem.anchor,\n");
    String.append(*js_builder, "                  title: item.title,\n");
    String.append(*js_builder, "                  displayTitle: subItem.name,\n");
    String.append(*js_builder, "                  displayType: subItem.type,\n");
    String.append(*js_builder, "                  displayContext: subItem.context,\n");
    String.append(*js_builder, "                  score: result.score\n");
    String.append(*js_builder, "                });\n");
    String.append(*js_builder, "              }\n");
    String.append(*js_builder, "            });\n");
    String.append(*js_builder, "          } else {\n");
    String.append(*js_builder, "            // Page-level match\n");
    String.append(*js_builder, "            processedResults.push({\n");
    String.append(*js_builder, "              url: item.url,\n");
    String.append(*js_builder, "              title: item.title,\n");
    String.append(*js_builder, "              displayTitle: item.title,\n");
    String.append(*js_builder, "              displayType: item.type || 'page',\n");
    String.append(*js_builder, "              displayContext: '',\n");
    String.append(*js_builder, "              score: result.score\n");
    String.append(*js_builder, "            });\n");
    String.append(*js_builder, "          }\n");
    String.append(*js_builder, "        } else {\n");
    String.append(*js_builder, "          // Legacy format or simple page match\n");
    String.append(*js_builder, "          processedResults.push({\n");
    String.append(*js_builder, "            url: item.url,\n");
    String.append(*js_builder, "            title: item.title,\n");
    String.append(*js_builder, "            displayTitle: item.title,\n");
    String.append(*js_builder, "            displayType: 'page',\n");
    String.append(*js_builder, "            displayContext: '',\n");
    String.append(*js_builder, "            score: result.score\n");
    String.append(*js_builder, "          });\n");
    String.append(*js_builder, "        }\n");
    String.append(*js_builder, "      });\n");
    String.append(*js_builder, "      \n");
    String.append(*js_builder, "      // Sort by score and limit results\n");
    String.append(*js_builder, "      processedResults.sort(function(a, b) { return a.score - b.score; });\n");
    String.append(*js_builder, "      const limitedResults = processedResults.slice(0, 20);\n");
    String.append(*js_builder, "      \n");
    String.append(*js_builder, "      // Generate structured HTML for results\n");
    String.append(*js_builder, "      if (limitedResults.length === 0) {\n");
    String.append(*js_builder, "        resultsDiv.innerHTML = '<div class=\"no-results\">No results found</div>';\n");
    String.append(*js_builder, "        resultsDiv.classList.add('show');\n");
    String.append(*js_builder, "        navigationManager.updateResults();\n");
    String.append(*js_builder, "      } else {\n");
    String.append(*js_builder, "        const resultsHtml = limitedResults.slice(0, 5).map(function(r) {\n");
    String.append(*js_builder, "          const contextText = r.displayContext ? r.displayContext : '';\n");
    String.append(*js_builder, "          const typeText = r.displayType ? r.displayType : 'page';\n");
    String.append(*js_builder, "          return '<a href=\"' + r.url + '\" class=\"search-result-item\">' +\n");
    String.append(*js_builder, "                   '<div class=\"result-title\">' + r.displayTitle + '</div>' +\n");
    String.append(*js_builder, "                   '<div class=\"result-type\">' + typeText + '</div>' +\n");
    String.append(*js_builder, "                   (contextText ? '<div class=\"result-context\">' + contextText + '</div>' : '') +\n");
    String.append(*js_builder, "                 '</a>';\n");
    String.append(*js_builder, "        }).join('');\n");
    String.append(*js_builder, "        resultsDiv.innerHTML = resultsHtml;\n");
    String.append(*js_builder, "        resultsDiv.classList.add('show');\n");
    String.append(*js_builder, "        navigationManager.updateResults();\n");
    String.append(*js_builder, "      }\n");
    String.append(*js_builder, "    });\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    // SearchNavigationManager class for keyboard navigation\n");
    String.append(*js_builder, "    function SearchNavigationManager(resultsContainer, searchInput) {\n");
    String.append(*js_builder, "      this.container = resultsContainer;\n");
    String.append(*js_builder, "      this.input = searchInput;\n");
    String.append(*js_builder, "      this.currentIndex = -1;\n");
    String.append(*js_builder, "      this.results = [];\n");
    String.append(*js_builder, "      \n");
    String.append(*js_builder, "      // Bind keyboard event handler\n");
    String.append(*js_builder, "      this.input.addEventListener('keydown', this.handleKeyDown.bind(this));\n");
    String.append(*js_builder, "    }\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    SearchNavigationManager.prototype.updateResults = function() {\n");
    String.append(*js_builder, "      this.results = Array.from(this.container.querySelectorAll('.search-result-item'));\n");
    String.append(*js_builder, "      this.currentIndex = -1;\n");
    String.append(*js_builder, "      this.clearHighlight();\n");
    String.append(*js_builder, "      this.addMouseListeners();\n");
    String.append(*js_builder, "    };\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    SearchNavigationManager.prototype.handleKeyDown = function(event) {\n");
    String.append(*js_builder, "      if (!this.container.classList.contains('show') || this.results.length === 0) {\n");
    String.append(*js_builder, "        return;\n");
    String.append(*js_builder, "      }\n");
    String.append(*js_builder, "      \n");
    String.append(*js_builder, "      switch(event.key) {\n");
    String.append(*js_builder, "        case 'ArrowDown':\n");
    String.append(*js_builder, "          event.preventDefault();\n");
    String.append(*js_builder, "          this.navigateDown();\n");
    String.append(*js_builder, "          break;\n");
    String.append(*js_builder, "        case 'ArrowUp':\n");
    String.append(*js_builder, "          event.preventDefault();\n");
    String.append(*js_builder, "          this.navigateUp();\n");
    String.append(*js_builder, "          break;\n");
    String.append(*js_builder, "        case 'Enter':\n");
    String.append(*js_builder, "          event.preventDefault();\n");
    String.append(*js_builder, "          this.selectResult();\n");
    String.append(*js_builder, "          break;\n");
    String.append(*js_builder, "        case 'Escape':\n");
    String.append(*js_builder, "          event.preventDefault();\n");
    String.append(*js_builder, "          this.hideResults();\n");
    String.append(*js_builder, "          break;\n");
    String.append(*js_builder, "      }\n");
    String.append(*js_builder, "    };\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    SearchNavigationManager.prototype.navigateDown = function() {\n");
    String.append(*js_builder, "      if (this.results.length === 0) return;\n");
    String.append(*js_builder, "      \n");
    String.append(*js_builder, "      this.currentIndex = (this.currentIndex + 1) % this.results.length;\n");
    String.append(*js_builder, "      this.highlightResult(this.currentIndex);\n");
    String.append(*js_builder, "      this.scrollToResult(this.currentIndex);\n");
    String.append(*js_builder, "    };\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    SearchNavigationManager.prototype.navigateUp = function() {\n");
    String.append(*js_builder, "      if (this.results.length === 0) return;\n");
    String.append(*js_builder, "      \n");
    String.append(*js_builder, "      this.currentIndex = this.currentIndex <= 0 ? this.results.length - 1 : this.currentIndex - 1;\n");
    String.append(*js_builder, "      this.highlightResult(this.currentIndex);\n");
    String.append(*js_builder, "      this.scrollToResult(this.currentIndex);\n");
    String.append(*js_builder, "    };\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    SearchNavigationManager.prototype.highlightResult = function(index) {\n");
    String.append(*js_builder, "      this.clearHighlight();\n");
    String.append(*js_builder, "      if (index >= 0 && index < this.results.length) {\n");
    String.append(*js_builder, "        this.results[index].classList.add('focused');\n");
    String.append(*js_builder, "      }\n");
    String.append(*js_builder, "    };\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    SearchNavigationManager.prototype.clearHighlight = function() {\n");
    String.append(*js_builder, "      this.results.forEach(function(result) {\n");
    String.append(*js_builder, "        result.classList.remove('focused');\n");
    String.append(*js_builder, "      });\n");
    String.append(*js_builder, "    };\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    SearchNavigationManager.prototype.scrollToResult = function(index) {\n");
    String.append(*js_builder, "      if (index >= 0 && index < this.results.length) {\n");
    String.append(*js_builder, "        const result = this.results[index];\n");
    String.append(*js_builder, "        const container = this.container;\n");
    String.append(*js_builder, "        const resultTop = result.offsetTop;\n");
    String.append(*js_builder, "        const resultBottom = resultTop + result.offsetHeight;\n");
    String.append(*js_builder, "        const containerTop = container.scrollTop;\n");
    String.append(*js_builder, "        const containerBottom = containerTop + container.clientHeight;\n");
    String.append(*js_builder, "        \n");
    String.append(*js_builder, "        if (resultTop < containerTop) {\n");
    String.append(*js_builder, "          container.scrollTop = resultTop;\n");
    String.append(*js_builder, "        } else if (resultBottom > containerBottom) {\n");
    String.append(*js_builder, "          container.scrollTop = resultBottom - container.clientHeight;\n");
    String.append(*js_builder, "        }\n");
    String.append(*js_builder, "      }\n");
    String.append(*js_builder, "    };\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    SearchNavigationManager.prototype.selectResult = function() {\n");
    String.append(*js_builder, "      if (this.currentIndex >= 0 && this.currentIndex < this.results.length) {\n");
    String.append(*js_builder, "        const selectedResult = this.results[this.currentIndex];\n");
    String.append(*js_builder, "        const href = selectedResult.getAttribute('href');\n");
    String.append(*js_builder, "        if (href) {\n");
    String.append(*js_builder, "          window.location.href = href;\n");
    String.append(*js_builder, "        }\n");
    String.append(*js_builder, "      }\n");
    String.append(*js_builder, "    };\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    SearchNavigationManager.prototype.hideResults = function() {\n");
    String.append(*js_builder, "      this.container.classList.remove('show');\n");
    String.append(*js_builder, "      this.container.innerHTML = '';\n");
    String.append(*js_builder, "      this.currentIndex = -1;\n");
    String.append(*js_builder, "      this.results = [];\n");
    String.append(*js_builder, "      this.input.focus();\n");
    String.append(*js_builder, "    };\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    // Add mouse interaction support\n");
    String.append(*js_builder, "    SearchNavigationManager.prototype.addMouseListeners = function() {\n");
    String.append(*js_builder, "      var self = this;\n");
    String.append(*js_builder, "      this.results.forEach(function(result, index) {\n");
    String.append(*js_builder, "        result.addEventListener('mouseenter', function() {\n");
    String.append(*js_builder, "          self.currentIndex = index;\n");
    String.append(*js_builder, "          self.highlightResult(index);\n");
    String.append(*js_builder, "        });\n");
    String.append(*js_builder, "        result.addEventListener('click', function(event) {\n");
    String.append(*js_builder, "          event.preventDefault();\n");
    String.append(*js_builder, "          self.currentIndex = index;\n");
    String.append(*js_builder, "          self.selectResult();\n");
    String.append(*js_builder, "        });\n");
    String.append(*js_builder, "      });\n");
    String.append(*js_builder, "    };\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    // Initialize navigation manager\n");
    String.append(*js_builder, "    const resultsDiv = document.getElementById('search-results');\n");
    String.append(*js_builder, "    const navigationManager = new SearchNavigationManager(resultsDiv, input);\n");
    String.append(*js_builder, "    \n");
    String.append(*js_builder, "    // Add click-outside-to-close functionality\n");
    String.append(*js_builder, "    document.addEventListener('click', function(event) {\n");
    String.append(*js_builder, "      const searchBar = document.querySelector('.search-bar');\n");
    String.append(*js_builder, "      const resultsDiv = document.getElementById('search-results');\n");
    String.append(*js_builder, "      if (searchBar && resultsDiv && !searchBar.contains(event.target)) {\n");
    String.append(*js_builder, "        navigationManager.hideResults();\n");
    String.append(*js_builder, "      }\n");
    String.append(*js_builder, "    });\n");
    String.append(*js_builder, "  }).catch(function(error) {\n");
    String.append(*js_builder, "    console.error('Failed to load search index:', error);\n");
    String.append(*js_builder, "  });\n");
    String.append(*js_builder, "});\n");
    search_js_content := String.builder_to_string(*js_builder);
    search_js_path := sprint("%/assets/js/search.js", options.output_directory);
    write_entire_file(search_js_path, search_js_content);
}

