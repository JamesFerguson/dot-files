#!/usr/local/bin/shimmed_env node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Test raycast scripting
// @raycast.mode fullOutput

// Optional parameters:
// @raycast.icon 🤖
// @raycast.argument1 { "type": "text", "placeholder": "Placeholder" }
// @raycast.packageName Jim Inc

// Documentation:
// @raycast.author pascal_blaze
// @raycast.authorURL https://raycast.com/pascal_blaze

console.log("Hello World! Argument1 value: " + process.argv.slice(2)[0] + "\n");
