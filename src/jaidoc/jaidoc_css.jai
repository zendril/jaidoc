// jaidoc_css.jai - CSS content for HTML documentation

GET_CSS_CONTENT :: () -> string {
    return #string END
/* General Body Styles */
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    line-height: 1.6;
    margin: 0;
    padding: 0;
    display: flex;
    background-color: #121212;
    color: #E0E0E0;
}

/* Left Sidebar Styles */
.left-sidebar {
    width: 240px;
    min-width: 240px;
    padding: 20px;
    background-color: #1A1A1A;
    height: 100vh;
    position: sticky;
    top: 0;
    overflow-y: auto;
}

.left-sidebar h2 {
    font-size: 1.5em;
    margin-bottom: 20px;
}

.search-bar input {
    width: 100%;
    padding: 8px;
    border-radius: 5px;
    border: 1px solid #333;
    background-color: #2C2C2C;
    color: #E0E0E0;
}

.nav-buttons {
    margin: 20px 0;
}

.nav-buttons button {
    width: 100%;
    padding: 10px;
    margin-bottom: 10px;
    border-radius: 5px;
    border: 1px solid #333;
    background-color: #2C2C2C;
    color: #E0E0E0;
    cursor: pointer;
}

.left-sidebar h3 {
    font-size: 0.9em;
    color: #888;
    margin-top: 20px;
    margin-bottom: 10px;
    letter-spacing: 1px;
}

.left-sidebar ul {
    list-style-type: none;
    padding: 0;
    margin: 0;
}

.left-sidebar li a {
    text-decoration: none;
    color: #E0E0E0;
    display: block;
    padding: 8px 10px;
    border-radius: 5px;
    transition: background-color 0.2s;
}

.left-sidebar li a:hover, .left-sidebar li a.active {
    background-color: #333;
}

/* Main Content Styles */
.main-content {
    flex-grow: 1;
    padding: 40px;
}

/* Right Navigation Styles */
.right-nav {
    width: 220px;
    min-width: 220px;
    padding: 20px;
    height: 100vh;
    position: sticky;
    top: 0;
    overflow-y: auto;
}

.right-nav h3 {
    margin-top: 40px;
    color: #888;
    font-size: 0.9em;
    letter-spacing: 1px;
}

.right-nav h3:first-child {
    margin-top: 0;
}

.right-nav ul {
    list-style-type: none;
    padding: 0;
    margin: 0;
}

.right-nav li a {
    text-decoration: none;
    color: #AAA;
    display: block;
    padding: 5px 0;
    border-radius: 3px;
    transition: color 0.2s;
}

.right-nav li a:hover {
    color: #E0E0E0;
}

/* Header Styles */
h1, h2, h3, h4, h5, h6 {
    scroll-margin-top: 20px;
    color: #E0E0E0;
}

h1 {
    font-size: 2.5em;
    padding-bottom: 10px;
    margin-bottom: 0;
}

h2 {
    font-size: 1.8em;
    border-bottom: 1px solid #333;
    padding-bottom: 5px;
}

.filepath {
    font-size: 0.9em;
    color: #888;
    margin-top: 0;
    margin-bottom: 0;
    padding-bottom: 0;
    border-bottom: none;
}

.module-import-path {
    font-size: 0.9em;
    color: #888;
    margin-top: 0;
    margin-bottom: 20px;
    border-bottom: 1px solid #333;
    padding-bottom: 10px;
}

/* Declaration Section Styles */
.declaration-section {
    margin-bottom: 40px;
}

.declaration-section h3 {
    color: #E0E0E0;
    margin-bottom: 20px;
    font-size: 1.5em;
    display: flex;
    align-items: center;
}

.section-icon {
    width: 20px;
    height: 20px;
    margin-right: 10px;
    vertical-align: middle;
}

.declaration-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 10px;
}

.declaration-header h4 {
    color: #E0E0E0;
    font-size: 1.2em;
    margin: 0;
}

.source-link {
    color: #888;
    font-size: 0.9em;
    text-decoration: none;
}

.source-link:hover {
    text-decoration: underline;
}

/* Code Block Styles */
.code-block {
    background-color: #1A1A1A;
    border: 1px solid #333;
    padding: 15px;
    border-radius: 5px;
    margin: 10px 0;
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, Courier, monospace;
    font-size: 0.9em;
    overflow-x: auto;
}

.code-block pre {
    margin: 0;
}

.hidden {
    display: none;
}

/* Link Styles */
a {
    color: #58A6FF;
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

/* Responsive Design */
@media (max-width: 1024px) {
    .right-nav {
        display: none;
    }
}

@media (max-width: 768px) {
    body {
        flex-direction: column;
    }
    
    .left-sidebar {
        width: 100%;
        height: auto;
        position: static;
    }
    
    .main-content {
        padding: 20px;
    }
}

/* Icon Styles for Right Nav */
.right-nav .icon {
    width: 16px; /* Adjust as needed */
    height: 16px; /* Adjust as needed */
    margin-right: 8px;
    vertical-align: middle;
}
END;
}
