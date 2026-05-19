#!/usr/bin/env node

const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const assetsDir = path.resolve(__dirname, '..');
const repoRoot = path.resolve(assetsDir, '..');
const privNodeDir = path.join(repoRoot, 'priv', 'node');
const bundlePath = path.join(privNodeDir, 'eval.js');
const wrapperSourcePath = path.join(assetsDir, 'src', 'eval_engine', 'lambda.js');
const vm2LibDir = path.join(assetsDir, 'node_modules', 'vm2', 'lib');
const vm2RuntimeFiles = ['bridge.js', 'setup-sandbox.js'];
const stagingDir = path.join(privNodeDir, 'eval-lambda-package');
const zipPath = path.join(privNodeDir, 'eval.zip');

function runDeployNode() {
  const yarnCommand = process.platform === 'win32' ? 'yarn.cmd' : 'yarn';

  execFileSync(yarnCommand, ['deploy-node'], {
    cwd: assetsDir,
    stdio: 'inherit',
  });
}

function ensureFileExists(filePath, description) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing ${description}: ${filePath}`);
  }
}

function stageBundleFiles() {
  fs.rmSync(stagingDir, { recursive: true, force: true });
  fs.mkdirSync(stagingDir, { recursive: true });

  fs.copyFileSync(bundlePath, path.join(stagingDir, 'eval.js'));
  fs.copyFileSync(wrapperSourcePath, path.join(stagingDir, 'index.js'));

  vm2RuntimeFiles.forEach((fileName) => {
    fs.copyFileSync(path.join(vm2LibDir, fileName), path.join(stagingDir, fileName));
  });
}

function createZip() {
  fs.rmSync(zipPath, { force: true });

  const zipEntries = ['eval.js', 'index.js', ...vm2RuntimeFiles];

  execFileSync('/usr/bin/zip', ['-q', '-r', zipPath, ...zipEntries], {
    cwd: stagingDir,
    stdio: 'inherit',
  });
}

function main() {
  runDeployNode();
  ensureFileExists(bundlePath, 'built eval bundle');
  ensureFileExists(wrapperSourcePath, 'eval Lambda wrapper');
  vm2RuntimeFiles.forEach((fileName) => {
    ensureFileExists(path.join(vm2LibDir, fileName), `vm2 runtime file ${fileName}`);
  });
  stageBundleFiles();
  createZip();

  process.stdout.write(`Created ${zipPath}\n`);
}

main();
