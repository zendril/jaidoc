Plugin :: Metaprogram_Plugin;
JaidocProcessor :: #import, file "../jaidoc_processor.jai"; // Import the library

Modules :: Table(string, [..]*Code_Declaration);

Jaidoc_Plugin :: struct {
    #as using base: Plugin;
    should_run := true;

    modules: Modules;
    options: JaidocProcessor.Jaidoc_Options; // Store options in plugin state
}

get_plugin :: () -> *Plugin {
    p := New(Jaidoc_Plugin);

    p.message  = message;
    p.shutdown = shutdown;
    // p.before_intercept = before_intercept;
    p.finish = finish;
    //p.add_source = add_source;

    init(*p.modules);
    
    // Initialize default options
    p.options.output_directory = "docs_from_plugin";

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
finish :: (p: *Metaprogram_Plugin) {
    JaidocProcessor.process_finish(cast(*Jaidoc_Plugin)p.options);
}


shutdown :: (_p: *Plugin) {
    p := cast(*Jaidoc_Plugin) _p;
    deinit(*p.modules);
    free(p);
}

// #load "../generator.jai";

#scope_module

#import "Basic";
#import "String";
#import "Compiler";
#import "Process";
#import "Hash_Table";
#import "File";
#import "File_Utilities";