// jaidoc_model.jai - Data model management for jaidoc

#import "Basic";
JaidocTypes :: #import, file "jaidoc_types.jai";

// Global data model and state
num_messages := 0;
target_files: [..]string;
doc_model: JaidocTypes.Documentation_Model;

// Helper functions for data model population
find_or_create_file_info :: (file_path: string, module_name: string = "") -> *JaidocTypes.File_Info {
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
    new_file: JaidocTypes.File_Info;
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

find_or_create_module_info :: (module_name: string) -> *JaidocTypes.Module_Info {
    for *module_info: doc_model.modules {
        if module_info.name == module_name {
            return module_info;
        }
    }
    
    // Create new module
    new_module: JaidocTypes.Module_Info;
    new_module.name = copy_string(module_name);
    new_module.import_path = copy_string(module_name); // For now, same as name
    array_add(*doc_model.modules, new_module);
    return *doc_model.modules[doc_model.modules.count - 1];
}

print_documentation_summary :: (options: JaidocTypes.Jaidoc_Options) {
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

cleanup_data_model :: () {
    // Clean up allocated memory
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
