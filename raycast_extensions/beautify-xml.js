#!/usr/local/bin/shimmed_env node
// @raycast.runtime node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Beautify XML
// @raycast.mode compact

// Optional parameters:
// @raycast.icon 🤖
// @raycast.packageName Jim Utils

// Documentation:
// @raycast.description Beautify the XML in the clipboard
// @raycast.author jim
// @raycast.authorURL @jafergus

const { execSync } = require('child_process');

try {
  // Get clipboard contents
  const clipboardContent = execSync('pbpaste', { encoding: 'utf-8' });
  
  if (!clipboardContent.trim()) {
    console.log("❌ Clipboard is empty");
    process.exit(1);
  }

  // Parse and beautify XML
  const formatXML = (xml) => {
    let formatted = '';
    let indent = 0;
    const tab = '  '; // 2 spaces
    
    xml.split(/>\s*</).forEach((node) => {
      if (node.match(/^\/\w/)) {
        indent--; // Closing tag
      }
      
      formatted += tab.repeat(indent) + '<' + node + '>\n';
      
      if (node.match(/^<?\w[^>]*[^\/]$/) && !node.startsWith("?")) {
        indent++; // Opening tag (not self-closing)
      }
    });
    
    return formatted.substring(1, formatted.length - 2);
  };

  const beautifiedXML = formatXML(clipboardContent.trim());
  
  // Copy back to clipboard
  execSync('pbcopy', { input: beautifiedXML });
  
  console.log("✅ XML beautified and copied to clipboard");
} catch (error) {
  console.log("❌ Error: " + error.message);
  process.exit(1);
}


