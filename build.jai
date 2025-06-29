#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
JaidocProcessor :: #import, file "jaidoc_processor.jai"; // Import the library

Command :: enum_flags u8 {
    CLEAN;
    BUILD;
    RELEASE;
}

#run {
    context.print_style.default_format_struct.use_long_form_if_more_than_this_many_members = -1;
    context.print_style.default_format_struct.use_newlines_if_long_form = true;

    // info_decl := type_info(Code_Declaration);
    // print("Code_Declaration Members:\n");
    // for info_decl.members {
    //     print("  % : %\n", it.name, it.type);
    // }

    // info_struct := type_info(Code_Struct);
    // print("\nCode_Struct Members:\n");
    // for info_struct.members {
    //     print("  % : %\n", it.name, it.type);
    // }

    // info_block := type_info(Code_Block);
    // print("\nCode_Block Members:\n");
    // for info_block.members {
    //     print("  % : %\n", it.name, it.type);
    // }

    // info_proc := type_info(Code_Procedure_Header);
    // print("\nCode_Procedure_Header Members:\n");
    // for info_proc.members {
    //     print("  % : %\n", it.name, it.type);
    // }

    // info_decl_flags := type_info(Code_Declaration);
    // flags_member_type: *Type_Info = null;
    // for member: info_decl_flags.members {
    //     if member.name == "flags" {
    //         flags_member_type = member.type;
    //         break;
    //     }
    // }

    // if flags_member_type {
    //     print("flags type: %\n", flags_member_type.type);
    //     info_enum := cast(*Type_Info_Enum) flags_member_type;
    //     print("\nCode_Declaration.flags enum names:\n");
    //     for name: info_enum.names {
    //         print("  %\n", name);
    //     }
    // }

    


    build_options_for_args := get_build_options();
    args := build_options_for_args.compile_time_command_line;


    // Configure Jaidoc and log level first
    sample_jaidoc_options: JaidocProcessor.Jaidoc_Options;
    if array_find(args, "-quiet") {
        sample_jaidoc_options.log_level = .QUIET;
    } else if array_find(args, "-verbose") {
        sample_jaidoc_options.log_level = .VERBOSE;
    } else {
        sample_jaidoc_options.log_level = .DEFAULT;
    }

    commands := parse_commands(args);
    if sample_jaidoc_options.log_level == .VERBOSE print("Commands: %\n", commands);
    
    // Always run clean first if specified, regardless of argument order
    if commands & .CLEAN {
        if sample_jaidoc_options.log_level != .QUIET print("Running clean ===\n");
        clean_target_directory();
    }

    sample_workspace := compiler_create_workspace("sample");
    if !sample_workspace {
        print("Sample workspace creation failed.\n");
        exit(1);
    }

    // Exit early if only clean was requested
    if commands == .CLEAN {
        // if sample_jaidoc_options.log_level != .QUIET print("exiting because clean was the only thing requested\n");
        set_build_options_dc(.{do_output=false}, sample_workspace);
        exit(0);
    }
        
    sample_options := get_build_options();

    // Create target directory if it doesn't exist
    sample_dir := "target/sample";
    success := make_directory_if_it_does_not_exist(sample_dir, true);
    if success {
        if sample_jaidoc_options.log_level == .VERBOSE print("Directory [%] created successfully!\n", sample_dir);
    } else {
        print("Failed to create [%].\n", sample_dir);
    }

    // Configure build options
    sample_options.output_executable_name = "sample";
    sample_options.output_path = "target/sample/";
    sample_options.intermediate_path = "target/sample/.build/";
    
    // Set optimization level if release flag is present
    if commands & .RELEASE {
        set_optimization(*sample_options, .OPTIMIZED);
    }
    
    new_path: [..] string;
    array_add(*new_path, ..sample_options.import_path); // Copy existing paths
    array_add(*new_path, tprint("%src/sample/modules", #filepath));
    sample_options.import_path = new_path;
    set_build_options(sample_options, sample_workspace);

    // Configure Jaidoc for this specific workspace
    sample_jaidoc_options.output_directory = "target/docs";
    sample_jaidoc_options.project_root = #filepath;


    compiler_begin_intercept(sample_workspace);
    add_build_file(tprint("%src/sample/sample.jai", #filepath), sample_workspace);
    

    while true {
        message := compiler_wait_for_message();
        if !message break;

        // Call the library directly
        JaidocProcessor.process_message(message, sample_jaidoc_options);

        if message.kind == .COMPLETE break;
    }
    compiler_end_intercept(sample_workspace);
    JaidocProcessor.process_finish(sample_jaidoc_options);

    // Tell the compiler that this build script itself doesn't produce an executable.
    // This prevents the default "Target Program" (Workspace 2) from trying to link.
    set_build_options_dc(.{do_output=false});    

    if sample_jaidoc_options.log_level != .QUIET print("Build complete with optimization: %\n", ifx commands & .RELEASE then "OPTIMIZED" else "DEFAULT");
}

parse_commands :: (args: [] string) -> Command {
    commands: Command = 0;
    
    for arg: args {
        if arg == {
            case "clean";
                commands |= .CLEAN;
            case "build";
                commands |= .BUILD;
            case "release";
                commands |= .RELEASE;

            case "-quiet";
                // Handled in main logic, ignore here
            case "-verbose";
                // Handled in main logic, ignore here
            case; // Default
                if arg.count > 0 && arg[0] == #char "-" {
                    // This is a compiler flag, ignore it.
                } else {
                    print("Unrecognized command: %\n", arg);
                }
        }
    }
    // Default to build if no commands specified
    if commands == 0 {
        commands = .BUILD;
    }
    
    return commands;
}

clean_target_directory :: () {
    target_dirs := string.["target", "build", "out"];

    for dir: target_dirs {
        if file_exists(dir) {
            success := delete_directory(dir);
            if success {
                print("    Cleaned: %\n", dir);
            } else {
                print("    Failed to clean: %\n", dir);
            }
        }
    }
}
