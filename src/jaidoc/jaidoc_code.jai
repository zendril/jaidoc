// jaidoc_code.jai - Source code extraction and processing

#import "Basic";
#import "Compiler";
#import "File";
#import "Hash_Table";
String :: #import "String";
JaidocTypes :: #import, file "jaidoc_types.jai";
JaidocUtils :: #import, file "jaidoc_utils.jai";

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

process_declaration :: (decl_info: *JaidocTypes.Declaration_Info, options: JaidocTypes.Jaidoc_Options) {
    if decl_info.code_declaration.expression {
        expr := decl_info.code_declaration.expression;
        code_declaration := decl_info.code_declaration;
        decl_info.expression_kind = expr.kind;
        decl_info.declaration_kind = JaidocUtils.get_declaration_kind(expr);

        if expr.kind == {
            case .PROCEDURE_HEADER;
                proc_header := cast(*Code_Procedure_Header) expr;
                if proc_header.body_or_null {
                    body := proc_header.body_or_null;
                    JaidocUtils.debug_print(options, "Procedure % body kind: %\n", decl_info.name, body.kind, indent_spaces = 4);
                    JaidocUtils.debug_print(options, "Procedure % body location: l0=%, c0=%, l1=%, c1=%\n", decl_info.name, body.location.l0, body.location.c0, body.location.l1, body.location.c1, indent_spaces = 4);
                    
                    // Check if the body is a PROCEDURE_BODY (which should have a block)
                    if body.kind == .PROCEDURE_BODY {
                        proc_body := cast(*Code_Procedure_Body) body;
                        if proc_body.block {
                            block := proc_body.block;
                            // Extend end location to include the block
                            decl_info.procedure_line_end_number = block.location.l1;
                            decl_info.procedure_column_end_number = block.location.c1;
                        }
                    }
                }
                decl_info.source_code = copy_string(extract_source_code(decl_info.file_path, decl_info.procedure_line_start_number, decl_info.procedure_line_end_number, decl_info.procedure_column_start_number, decl_info.procedure_column_end_number));
                decl_info.declaration_code = copy_string(extract_source_code(decl_info.file_path, decl_info.procedure_line_start_number, decl_info.procedure_line_end_number, decl_info.procedure_column_start_number, decl_info.procedure_column_end_number));
            case .PROCEDURE_BODY;
                proc_body := cast(*Code_Procedure_Body) expr;
                // For procedure bodies, use the body's location directly
                decl_info.procedure_line_end_number = proc_body.location.l1;
                decl_info.procedure_column_end_number = proc_body.location.c1;
                JaidocUtils.debug_print(options, "Found PROCEDURE_BODY for '%' - extending to line %\n", decl_info.name, decl_info.procedure_line_end_number, indent_spaces = 4);
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
                JaidocUtils.debug_print(options, "Unhandled expression kind for '%': %\n", decl_info.name, expr.kind);
        }
    } else {
        JaidocUtils.debug_print(options, "No expression for declaration '%': %\n", decl_info.name);
    }
    JaidocUtils.debug_print(options, "Declaration Info: %\n", decl_info.*, indent_spaces = 4);
}
