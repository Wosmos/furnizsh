#!/usr/bin/env node
/* ============================================================
 *  furnizsh — npm entry point
 *  https://github.com/Wosmos/furnizsh
 *
 *  Node is only the delivery mechanism here. This file locates the
 *  payload that ships alongside it and hands off to the real script:
 *  install.sh on macOS/Linux, install.ps1 on Windows.
 *
 *      npx furnizsh install
 *      npm i -g furnizsh && furnizsh install
 *
 *  Nothing is installed, downloaded or written by requiring this file —
 *  there is deliberately no postinstall hook. Setting up your shell only
 *  happens when you run `furnizsh install` yourself.
 * ============================================================ */

'use strict';

const { spawn } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');

const PAYLOAD = path.join(__dirname, '..', 'payload');
const IS_WINDOWS = process.platform === 'win32';

function readVersion() {
  try {
    return fs.readFileSync(path.join(PAYLOAD, 'VERSION'), 'utf8').trim();
  } catch {
    return require('../package.json').version;
  }
}

function usage() {
  console.log(`furnizsh ${readVersion()} — a neon terminal, in one command

  furnizsh <command> [flags]

Commands:
  install      set up the terminal   (furnizsh install --help for flags)
  uninstall    remove it, restore backups
  doctor       health-check every part of the setup
  theme [name] list themes, or switch to one
  version      show installed and packaged version
  help         this message

Examples:
  furnizsh install --dry-run
  furnizsh install --theme gruvbox --tools extended
  furnizsh theme catppuccin

Docs: https://wosmos.github.io/furnizsh`);
}

/**
 * Run a payload script, inheriting stdio so prompts and colour work.
 * Resolves with the child's exit code rather than throwing, so the
 * caller controls the process exit.
 */
function run(script, args) {
  const target = path.join(PAYLOAD, script);

  if (!fs.existsSync(target)) {
    console.error(`furnizsh: missing payload file ${script}.`);
    console.error('The package looks incomplete — try reinstalling it.');
    process.exit(1);
  }

  let cmd, cmdArgs;
  if (script.endsWith('.ps1')) {
    // -NoProfile so the user's own profile can't interfere mid-install,
    // -ExecutionPolicy Bypass because the file is unsigned by design.
    cmd = process.env.PWSH || 'powershell';
    cmdArgs = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', target, ...args];
  } else {
    cmd = 'bash';
    cmdArgs = [target, ...args];
  }

  const child = spawn(cmd, cmdArgs, {
    stdio: 'inherit',
    env: { ...process.env, FURNIZSH_SHARE: PAYLOAD },
  });

  child.on('error', (err) => {
    if (err.code === 'ENOENT') {
      console.error(`furnizsh: ${cmd} not found on PATH.`);
      if (IS_WINDOWS) {
        console.error('Install PowerShell 7: winget install Microsoft.PowerShell');
      } else {
        console.error('bash is required to run the installer.');
      }
    } else {
      console.error(`furnizsh: ${err.message}`);
    }
    process.exit(1);
  });

  child.on('exit', (code, signal) => {
    if (signal) process.kill(process.pid, signal);
    else process.exit(code ?? 0);
  });
}

function version() {
  console.log(`furnizsh ${readVersion()}  (npm package)`);
  console.log(`  payload:   ${PAYLOAD}`);

  const installed = path.join(os.homedir(), '.config', 'furnizsh', 'VERSION');
  if (fs.existsSync(installed)) {
    console.log(`  installed: ${fs.readFileSync(installed, 'utf8').trim()}`);
  } else {
    console.log('  installed: not installed — run `furnizsh install`');
  }
}

function main() {
  const [command = 'help', ...args] = process.argv.slice(2);

  // Windows has no Ghostty and no zsh, so it gets the PowerShell scripts.
  // WSL reports linux, which is correct — it should take the Unix path.
  const script = (base) => (IS_WINDOWS ? `${base}.ps1` : `${base}.sh`);

  switch (command) {
    case 'install':
      return run(script('install'), args);
    case 'uninstall':
    case 'remove':
      return run(script('uninstall'), args);
    case 'doctor':
    case 'check':
      return run(script('doctor'), args);
    case 'theme':
      // Switching themes is just an install with only the theme applied —
      // one code path, same backups, same validation.
      if (args.length === 0) {
        const dir = path.join(PAYLOAD, 'config', 'themes');
        console.log('\nThemes  (furnizsh theme <name> to switch)\n');
        for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.theme'))) {
          const body = fs.readFileSync(path.join(dir, file), 'utf8');
          const label = /^THEME_LABEL="(.*)"$/m.exec(body)?.[1] ?? '';
          console.log(`  ${file.replace('.theme', '').padEnd(12)} ${label}`);
        }
        console.log('');
        return;
      }
      return IS_WINDOWS
        ? run('install.ps1', ['-Theme', args[0], '-Yes', '-NoFont'])
        : run('install.sh', ['--theme', args[0], '--yes', '--no-font', '--no-chsh', '--no-claude']);
    case 'version':
    case '--version':
    case '-v':
      return version();
    case 'help':
    case '--help':
    case '-h':
      return usage();
    default:
      console.error(`furnizsh: unknown command '${command}'\n`);
      usage();
      process.exit(1);
  }
}

main();
