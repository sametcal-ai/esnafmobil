#!/usr/bin/env node

/**
 * Simple version bump script for the Expo app.
 *
 * Responsibilities:
 * - Bump expo.version in app.json (semver: major/minor/patch).
 * - Increment expo.ios.buildNumber (numeric string).
 * - Increment expo.android.versionCode (number).
 * - Keep package.json version in sync with expo.version.
 *
 * Usage:
 *   npm run bump:patch
 *   npm run bump:minor
 *   npm run bump:major
 */

const fs = require('fs');
const path = require('path');

const BUMP_TYPES = ['major', 'minor', 'patch'];

function readJson(relPath) {
  const fullPath = path.join(__dirname, '..', relPath);
  const raw = fs.readFileSync(fullPath, 'utf8');
  return { fullPath, data: JSON.parse(raw) };
}

function writeJson(fullPath, data) {
  const json = JSON.stringify(data, null, 2) + '\n';
  fs.writeFileSync(fullPath, json, 'utf8');
}

function bumpSemver(version, bumpType) {
  const match = /^(\d+)\.(\d+)\.(\d+)$/.exec(version.trim());
  if (!match) {
    throw new Error(
      `Unsupported version format "${version}". Expected MAJOR.MINOR.PATCH (e.g. 1.2.3).`
    );
  }

  let [_, major, minor, patch] = match; // eslint-disable-line no-unused-vars
  major = Number(major);
  minor = Number(minor);
  patch = Number(patch);

  if (!Number.isInteger(major) || !Number.isInteger(minor) || !Number.isInteger(patch)) {
    throw new Error(`Version components must be integers. Got: ${version}`);
  }

  if (bumpType === 'major') {
    major += 1;
    minor = 0;
    patch = 0;
  } else if (bumpType === 'minor') {
    minor += 1;
    patch = 0;
  } else {
    patch += 1;
  }

  return `${major}.${minor}.${patch}`;
}

function bumpExpoConfig(bumpType) {
  const { fullPath, data } = readJson('app.json');

  if (!data.expo) {
    throw new Error('app.json does not contain an "expo" root object.');
  }

  const expo = data.expo;
  const currentVersion = typeof expo.version === 'string' ? expo.version : '1.0.0';
  const nextVersion = bumpSemver(currentVersion, bumpType);

  expo.version = nextVersion;

  // iOS buildNumber is a string but must be numeric.
  const ios = expo.ios || {};
  const currentBuildNumber = ios.buildNumber ? Number(ios.buildNumber) : 0;
  const nextBuildNumber = Number.isFinite(currentBuildNumber)
    ? currentBuildNumber + 1
    : 1;
  ios.buildNumber = String(nextBuildNumber);
  expo.ios = ios;

  // Android versionCode is numeric.
  const android = expo.android || {};
  const currentVersionCode =
    typeof android.versionCode === 'number' ? android.versionCode : 0;
  const nextVersionCode = Number.isFinite(currentVersionCode)
    ? currentVersionCode + 1
    : 1;
  android.versionCode = nextVersionCode;
  expo.android = android;

  writeJson(fullPath, data);

  return nextVersion;
}

function syncPackageJsonVersion(nextVersion) {
  const { fullPath, data } = readJson('package.json');
  data.version = nextVersion;
  writeJson(fullPath, data);
}

function bumpFlutterPubspec(nextVersion) {
  const fullPath = path.join(__dirname, '..', 'flutter_app', 'pubspec.yaml');

  if (!fs.existsSync(fullPath)) {
    return;
  }

  const raw = fs.readFileSync(fullPath, 'utf8');

  // Matches lines like: version: 1.0.0+1
  const versionLineRegex = /^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$/m;
  const match = raw.match(versionLineRegex);

  if (!match) {
    console.warn(
      'Could not find a version line in flutter_app/pubspec.yaml with the expected format "version: x.y.z+build". Skipping Flutter bump.'
    );
    return;
  }

  const currentBuild = Number(match[2]);
  const nextBuild = Number.isFinite(currentBuild) ? currentBuild + 1 : 1;

  const nextLine = `version: ${nextVersion}+${nextBuild}`;
  const updated = raw.replace(versionLineRegex, nextLine);

  fs.writeFileSync(fullPath, updated, 'utf8');
}

function main() {
  const bumpType = (process.argv[2] || 'patch').toLowerCase();
  if (!BUMP_TYPES.includes(bumpType)) {
    console.error(
      `Invalid bump type \"${bumpType}\". Use one of: ${BUMP_TYPES.join(', ')}.`
    );
    process.exit(1);
  }

  try {
    const nextVersion = bumpExpoConfig(bumpType);
    syncPackageJsonVersion(nextVersion);
    bumpFlutterPubspec(nextVersion);
    console.log(
      `Version bumped to ${nextVersion} (${bumpType}). iOS buildNumber and Android versionCode were incremented as well. Flutter pubspec.yaml version was synced and its build number incremented if present.`
    );
  } catch (error) {
    console.error('Error while bumping version:', error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

main();