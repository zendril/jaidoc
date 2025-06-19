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

num_messages := 0;
target_files: [..]string;


// This is the core logic extracted from the plugin
process_message :: (message: *Message, options: Jaidoc_Options) {
    num_messages += 1;
    if message.kind == {
      case .PHASE;
        mp := cast(*Message_Phase) message;
        debug_print(options, "Now in phase: %\n", mp.phase);
        
      case .FILE;
        mf := cast(*Message_File) message;
        if mf.enclosing_import != null && mf.enclosing_import.module_type == .MAIN_PROGRAM {
            debug_print(options, "Now in file: %\n", mf.fully_pathed_filename);
            array_add(*target_files, copy_string(mf.fully_pathed_filename));
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

                if code_declaration.expression {
                    // if code_declaration.flags & .IS_CONSTANT {
                        expr := code_declaration.expression;
                        debug_print(options, "code_declaration.expression.kind: %\n", expr.kind);
                    // }
                    
                }

            }
        }
        
      case .COMPLETE;
        debug_print(options, "Got COMPLETE.\n");
    }
}

process_finish :: (options: Jaidoc_Options) {
    debug_print(options, "JaidocProcessor finished, which saw % messages.\n", num_messages);
    array_free(target_files);
}
