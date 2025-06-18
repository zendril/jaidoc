#import "Basic"; // For print

starter := 0;

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

    print("Starter: %\n", starter);
}
