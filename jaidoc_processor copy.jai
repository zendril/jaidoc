// jaidoc_processor.jai - Main documentation processing entry point
// Now properly modularized with separate files for different functionality

#import "Compiler";
#import "Basic";
#import "File";
String :: #import "String";

// Import all jaidoc modules
JaidocTypes :: #import, file "jaidoc_types.jai";
JaidocUtils :: #import, file "jaidoc_utils.jai";
JaidocCode :: #import, file "jaidoc_code.jai";
JaidocModel :: #import, file "jaidoc_model.jai";
JaidocHTML :: #import, file "jaidoc_html.jai";

// Re-export key functions and types for easier access
Jaidoc_Options :: JaidocTypes.Jaidoc_Options;
LogLevel :: JaidocTypes.LogLevel;
Declaration_Info :: JaidocTypes.Declaration_Info;

process_message :: (message: *Message, options: Jaidoc_Options) {
    JaidocModel.num_messages += 1;
    if message.kind == {
      case .PHASE;
        mp := cast(*Message_Phase) message;
        JaidocUtils.debug_print(options, "\nPHASE: %\n", mp.phase);
        
      case .FILE;
        mf := cast(*Message_File) message;

        if mf.enclosing_import != null && mf.enclosing_import.module_type == .MAIN_PROGRAM {
            JaidocUtils.debug_print(options, "\nFILE:\n", indent_spaces = 2);
            JaidocUtils.debug_print(options, "Local main filename: %\n", mf.fully_pathed_filename, indent_spaces = 4);
            JaidocUtils.debug_print(options, "with enclosing_import.module_name: %\n", ifx mf.enclosing_import.module_name == "" "none" else mf.enclosing_import.module_name, indent_spaces = 6);
            array_add(*JaidocModel.target_files, copy_string(mf.fully_pathed_filename));
            
            // Create file info for main program files
            JaidocModel.find_or_create_file_info(mf.fully_pathed_filename, "");
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
                    
                    if char_file != char_root {
                        match = false;
                        break;
                    }
                }
                is_local = match;
            }
            
            if is_local {
                JaidocUtils.debug_print(options, "\nLOCAL MODULE FILE:\n", indent_spaces = 2);
                JaidocUtils.debug_print(options, "Local module filename: %\n", mf.fully_pathed_filename, indent_spaces = 4);
                JaidocUtils.debug_print(options, "with enclosing_import.module_name: %\n", ifx mf.enclosing_import.module_name == "" "none" else mf.enclosing_import.module_name, indent_spaces = 6);
                array_add(*JaidocModel.target_files, copy_string(mf.fully_pathed_filename));
                
                // Create file info for module files
                module_name := ifx mf.enclosing_import.module_name == "" "<unnamed>" else mf.enclosing_import.module_name;
                JaidocModel.find_or_create_file_info(mf.fully_pathed_filename, module_name);
            }
        }
        // TODO support file_message.from_a_string

      case .TYPECHECKED;
        tc := cast(*Message_Typechecked) message;
        for typechecked: tc.declarations {
            // code_declaration is Compiler.Code_Node
            code_declaration := typechecked.expression;

            filename := code_declaration.location.enclosing_load.fully_pathed_filename;
            if array_find(JaidocModel.target_files, filename) {
                JaidocUtils.debug_print(options, "\nTYPECHECKED:\n", indent_spaces = 2);
                JaidocUtils.debug_print(options, "Local filename: %\n", filename, indent_spaces = 4);

                declname := code_declaration.entry.name;

                // Create declaration info and add to data model
                decl_info: Declaration_Info;
                
                decl_info.name = copy_string(declname);
                decl_info.file_path = copy_string(filename);
                decl_info.declaration_line_start_number = code_declaration.location.l0;
                decl_info.declaration_column_start_number = code_declaration.location.c0;
                decl_info.declaration_line_end_number = code_declaration.location.l1;
                decl_info.declaration_column_end_number = code_declaration.location.c1;
                decl_info.procedure_line_start_number = code_declaration.location.l0;
                decl_info.procedure_line_end_number = code_declaration.location.l1;
                decl_info.procedure_column_start_number = code_declaration.location.c0;
                decl_info.procedure_column_end_number = code_declaration.location.c1;
                decl_info.is_public = JaidocUtils.is_declaration_public(code_declaration);
                decl_info.code_declaration = code_declaration;
                
                // Add declaration to the appropriate file
                file_info := JaidocModel.find_or_create_file_info(filename);
                array_add(*file_info.declarations, decl_info);
            }
        }

      case .COMPLETE;
        JaidocUtils.debug_print(options, "COMPLETE.\n");

        // let's loop through all of the declarations in both main files and modules and write the declaration name and the body_or_null value
        for file_info: JaidocModel.doc_model.main_files {
            for *decl_info: file_info.declarations {
                JaidocCode.process_declaration(decl_info, options);
            }
        }

        for module_info: JaidocModel.doc_model.modules {
            for file_info: module_info.files {
                for *decl_info: file_info.declarations {
                    JaidocCode.process_declaration(decl_info, options);
                }
            }
        }   
        JaidocModel.print_documentation_summary(options);
        JaidocHTML.generate_html_docs(options);
    }
}

process_finish :: (options: Jaidoc_Options) {
    if options.log_level == .VERBOSE {
        print("JaidocProcessor finished, which saw % messages.\n", JaidocModel.num_messages);
    }
    
    // Generate HTML documentation
    JaidocHTML.generate_html_docs(options);
    
    // Clean up allocated memory
    JaidocModel.cleanup_data_model();
}
