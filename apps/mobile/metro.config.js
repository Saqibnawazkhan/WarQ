// Metro, taught about the monorepo.
//
// Two things are needed that a standalone Expo app does not have:
//
//   watchFolders  — so a change in packages/core reloads the app rather than
//                   being invisible until the next restart.
//   nodeModulesPaths — so a dependency hoisted to the repository root resolves
//                   from here, since npm workspaces installs almost everything
//                   at the top rather than inside each app.
//
// disableHierarchicalLookup is deliberately left off: with it on, a package that
// legitimately lives in apps/mobile/node_modules stops resolving.

const { getDefaultConfig } = require('expo/metro-config');
const path = require('node:path');

const projectRoot = __dirname;
const workspaceRoot = path.resolve(projectRoot, '../..');

const config = getDefaultConfig(projectRoot);

config.watchFolders = [workspaceRoot];

config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(workspaceRoot, 'node_modules'),
];

module.exports = config;
