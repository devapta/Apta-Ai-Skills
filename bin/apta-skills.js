#!/usr/bin/env node
// npx entry point: hands every argument to install.sh, which holds all the logic.
// stdio is inherited so the checkbox pickers still get the TTY, and the cwd is
// the caller's so the default target stays "the project you ran this in".

"use strict";

const { spawnSync } = require("node:child_process");
const path = require("node:path");

const installer = path.join(__dirname, "..", "install.sh");
const res = spawnSync("bash", [installer, ...process.argv.slice(2)], { stdio: "inherit" });

if (res.error) {
  console.error(`apta-skills: could not run bash (${res.error.message})`);
  process.exit(1);
}
if (res.signal) process.kill(process.pid, res.signal);
process.exit(res.status ?? 1);
