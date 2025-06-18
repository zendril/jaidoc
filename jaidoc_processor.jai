// jaidoc_processor.jai - Core documentation processing library

// Compiler :: #import "Compiler";
#import "Compiler";
#import "Basic";
#import "File";
#import "String";

Jaidoc_Options :: struct {
    output_directory: string = "docs";
    // ... other options can be added later ...
}

num_messages := 0;

// This is the core logic extracted from the plugin
process_message :: (message: *Message, options: Jaidoc_Options) {
    num_messages += 1;
    if message.kind == {
      case .PHASE;
        mp := cast(*Message_Phase) message;
        print("Now in phase: %\n", mp.phase);

        if mp.phase == .PRE_WRITE_EXECUTABLE {
            print(".... The executable name will be: '%\n", mp.executable_name);
        }
        
      case .TYPECHECKED;
        tc := cast(*Message_Typechecked) message;
        // print("Typechecked: % declarations, % procedure headers, % procedure bodies, % structs, % others.\n", tc.declarations.count, tc.procedure_headers.count, tc.procedure_bodies.count, tc.structs.count, tc.others.count);
        
        for typechecked: tc.declarations {
            decl := typechecked.expression;

            // if !(decl.flags & .IS_GLOBAL) || !decl.expression continue;
            // if !decl.location.enclosing_load || !decl.location.enclosing_load.enclosing_import continue;

            filename := decl.location.enclosing_load.fully_pathed_filename;
            if ends_with(filename, "sample.jai") {


                print("File: %\n", filename);

                declname := decl.entry.name;
                print("Declaration: %\n", declname);

                print("Kind: %\n", decl.entry.base.kind);

                print("Type: %\n", <<decl.type);

                print("Name: %\n", decl.name);

            }
            //print("Module: %\n", module_name);
            // module := find_or_add(*p.modules, module_name);

            // array_add(module, decl);
        }
        
      case .COMPLETE;
        print("Got COMPLETE.\n");
    }
}

process_finish :: (options: Jaidoc_Options) {
    print("JaidocProcessor finished, which saw % messages.\n", num_messages);
}
