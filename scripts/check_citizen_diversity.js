#!/usr/bin/env node
// Backward-compatible entry point: exercise the production system, not a stale copied model.
require('child_process').execFileSync(process.execPath, [require('path').join(__dirname, 'check_character_design.js')], { stdio: 'inherit' });
