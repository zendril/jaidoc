// jaidoc_processor.jai - Core documentation processing library

// Compiler :: #import "Compiler";
#import "Compiler";
#import "Basic";
#import "File";
#import "String";

Jaidoc_Options :: struct {
    output_directory: string = "docs";
    debug: bool = false;
    // ... other options can be added later ...

}

debug_print :: (options: Jaidoc_Options, fmt: string, args: ..Any) {
    if options.debug {
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
            array_add(*target_files, copy_string(mf.fully_pathed_filename));
            
            // Create file info for main program files
            find_or_create_file_info(mf.fully_pathed_filename);
        }

        if mf.enclosing_import != null && mf.enclosing_import.module_type == .FILE {
            debug_print(options, "Now in file (file): %\n", mf.fully_pathed_filename);
            
            // Check if this is a local module (not standard library)
            // We consider it local if it's in a subdirectory of our project
            filename := mf.fully_pathed_filename;
            project_root := "C:/devhome/projects/github/zendril/jaidoc/"; // TODO: Make this configurable
            
            if begins_with(filename, project_root) {
                debug_print(options, "Found local module file: %\n", filename);
                
                // Extract module name from the import
                if mf.enclosing_import && mf.enclosing_import.module_name {
                    module_name := mf.enclosing_import.module_name;
                    debug_print(options, "Module name: %\n", module_name);
                    
                    // Create or find module info and add this file
                    find_or_create_file_info(filename, module_name);
                    array_add(*target_files, copy_string(filename));
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
                    debug_print(options, "code_declaration.expression.kind: %\n", expr.kind);
                    
                    decl_info.kind = get_declaration_kind(expr);
                    decl_info.type_string = copy_string(extract_type_info(expr));
                    
                    // Extract additional information based on declaration kind
                    if decl_info.kind == .PROCEDURE {
                        // TODO: Extract procedure parameters and return type
                        decl_info.return_type = copy_string("void"); // Placeholder
                    } else if decl_info.kind == .STRUCT || decl_info.kind == .ENUM {
                        // TODO: Extract struct/enum members
                    }
                } else {
                    decl_info.kind = .VARIABLE;
                    decl_info.type_string = copy_string("unknown");
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
    print("\n=== Documentation Model Summary ===\n");
    
    print("Main Program Files: %\n", doc_model.main_files.count);
    for file_info: doc_model.main_files {
        print("  File: %\n", file_info.path);
        print("    Declarations: %\n", file_info.declarations.count);
        for decl: file_info.declarations {
            print("      - % (%s) [%d:%d]\n", decl.name, decl.kind, decl.line_number, decl.column_number);
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
                print("        - % (%s) [%d:%d]\n", decl.name, decl.kind, decl.line_number, decl.column_number);
            }
        }
    }
}

process_finish :: (options: Jaidoc_Options) {
    debug_print(options, "JaidocProcessor finished, which saw % messages.\n", num_messages);
    
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
