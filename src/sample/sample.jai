#import "Basic"; // For print
#import "SampleModule";

starter := 0;

// Public Struct: Represents a 2D point
Point :: struct {
    x: float;
    y: float;
}

Number :: union {
    i: int;
    f: float;
}

// Public Enum: Represents basic colors
Color :: enum {
    RED;
    GREEN;
    BLUE;
    YELLOW;
}

global_message : string = "Hello, from a global variable!";

// Public procedure 1: Adds two integers
sum :: (a: int, b: int) -> int {
    return a + b;
}

// Public procedure 2: Greets a person
greet :: (name: string) {
    print("Hello, %!\n", name);
}

// Main entry point for the sample application
main :: () {
    print("Sample App: Starting execution...\n");

    // Example usage of public procedure 'sum'
    result := sum(25, 17);
    print("The sum of 25 and 17 is: %\n", result);

    // Example usage of public procedure 'greet'
    greet("Jaidoc Developer");

    print("Sample App: Execution finished.\n");

    speak_poetry();

    print("Starter: %\n", starter);

    // Example usage of public struct 'Point'
    p: Point;
    p.x = 10.0;
    p.y = 20.0;
    print("Point coordinates: (%, %)\n", p.x, p.y);

    // Example usage of public enum 'Color'
    my_color := Color.GREEN;
    print("My favorite color is: %\n", my_color);
}
