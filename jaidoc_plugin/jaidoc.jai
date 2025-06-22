Plugin :: Metaprogram_Plugin;
JaidocProcessor :: #import, file "../jaidoc_processor.jai"; // Import the library

Modules :: Table(string, [..]*Code_Declaration);

Jaidoc_Plugin :: struct {
    #as using base: Plugin;
    should_run := true;

    options: JaidocProcessor.Jaidoc_Options; // Store options in plugin state
}

get_plugin :: () -> *Plugin {
    p := New(Jaidoc_Plugin);

    p.message  = message;
    p.shutdown = shutdown;
    p.init = init;
    // p.before_intercept = before_intercept;
    p.finish = finish;
    //p.add_source = add_source;

    // Initialize default options
    p.options.output_directory = "target/docs";
    p.options.debug = true; // Enable debug by default when using plugin

    return p;   
}

add_source :: (_p: *Metaprogram_Plugin) {
    p := cast(*Jaidoc_Plugin) _p;
}

before_intercept :: (_p: *Plugin, flags: *Intercept_Flags) {
    p := cast(*Jaidoc_Plugin) _p;

    options := get_build_options(p.workspace);
    options.output_type = .NO_OUTPUT; // Do not output any binary files. 
    set_build_options(options, p.workspace);
}

// 'message' is called for each Compiler_Message received by the metaprogram.
message :: (_p: *Metaprogram_Plugin, message: *Message) {
    p := cast(*Jaidoc_Plugin) _p;
    
    // Use the library's process_message function
    JaidocProcessor.process_message(message, p.options);
}

// 'finish' is called after all messages are processed. You can use this to
// generate an output report, write to a file, etc.
finish :: (_p: *Metaprogram_Plugin) {
    p := cast(*Jaidoc_Plugin) _p;
    JaidocProcessor.process_finish(p.options);
}


init :: (_p: *Metaprogram_Plugin, options: [] string) -> bool {
    p := cast(*Jaidoc_Plugin) _p;
    
    // Get the project root - use the current working directory where jai was invoked
    p.options.project_root = get_working_directory();
    JaidocProcessor.debug_print(p.options, "Plugin: Detected project root: %", p.options.project_root);
    JaidocProcessor.debug_print(p.options, "Plugin: Current working directory: %", get_working_directory());
    JaidocProcessor.debug_print(p.options, "Plugin: Project root is same as current working directory: %", p.options.project_root == get_working_directory());
    
    cursor := 0;
    while cursor < options.count {
        s := options[cursor];
        if s == {
          case "-verbose";
            p.options.debug = true;
            cursor += 1;
          case "-output";
            if cursor + 1 >= options.count {
                log_error("Command line for plugin Jaidoc_Plugin: -output requires a directory argument.\n");
                return false;
            }
            p.options.output_directory = options[cursor + 1];
            cursor += 2;
          case;
            log_error("Command line for plugin Jaidoc_Plugin: Unknown argument '%'.\n", s);
            return false;
        }
    }
    return true;
}

shutdown :: (_p: *Plugin) {
    p := cast(*Jaidoc_Plugin) _p;
    free(p);
}

#scope_module

#import "Basic";
#import "String";
#import "Compiler";
#import "Process";
#import "Hash_Table";
#import "File";
#import "File_Utilities";