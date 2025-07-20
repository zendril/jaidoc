// jaidoc_types.jai - Core data structures and enums for jaidoc

#import "Compiler";

LogLevel :: enum {
    QUIET;
    DEFAULT;
    VERBOSE;
}

Jaidoc_Options :: struct {
    output_directory: string = "docs";
    project_root: string = "";  // Root directory of the project being documented
    log_level: LogLevel = .DEFAULT;
    app_title: string = "Jaidoc";  // Custom application title for documentation
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
