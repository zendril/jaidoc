// jaidoc_utils.jai - Utility functions for jaidoc

#import "Basic";
#import "Compiler";
String :: #import "String";
JaidocTypes :: #import, file "jaidoc_types.jai";

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

path_strip_filename :: (path: string) -> string {
    last_slash := -1;
    for i: 0..path.count-1 {
        if path[i] == #char "/" || path[i] == #char "\\" {
            last_slash = i;
        }
    }

    if last_slash == -1 {
        return ".";
    }

    result := path;
    result.count = last_slash;
    return result;
}

debug_print :: (options: JaidocTypes.Jaidoc_Options, fmt: string, args: ..Any, indent_spaces := 0) {
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

get_icon_path :: (kind: JaidocTypes.Declaration_Kind) -> string {
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

shorten_file_path :: (absolute_path: string, project_root: string) -> string {
    if project_root.count == 0 {
        // If no project root is provided, return just the filename
        return get_filename_from_path(absolute_path);
    }
    
    // Normalize path separators to forward slashes for consistent comparison
    normalized_path := String.replace(absolute_path, "\\", "/");
    normalized_root := String.replace(project_root, "\\", "/");
    
    // Ensure project root ends with a separator for proper prefix matching
    root_with_separator := normalized_root;
    if !String.ends_with(root_with_separator, "/") {
        root_with_separator = tprint("%/", root_with_separator);
    }
    
    // Check if the path starts with the project root
    if String.starts_with(normalized_path, root_with_separator) {
        // Remove the project root prefix
        relative_path := String.slice(normalized_path, root_with_separator.count, normalized_path.count);
        return relative_path;
    } else if normalized_path == normalized_root {
        // Handle case where the file is exactly at the project root
        return get_filename_from_path(absolute_path);
    } else {
        // Project root not found in path, fall back to filename only
        return get_filename_from_path(absolute_path);
    }
}

get_declaration_kind :: (expr: *Code_Node) -> JaidocTypes.Declaration_Kind {
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
