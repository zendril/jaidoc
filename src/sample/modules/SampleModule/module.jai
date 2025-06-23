#import "Basic";

module_status_code: int = 200;

Module_Data :: union {
    text: string;
    code: int;
};

speak_poetry :: () {
    print("I'm a poet and don't know it\n");
}
