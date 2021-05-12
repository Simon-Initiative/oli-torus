/* eslint-disable */
const path = require('path');

module.exports = (env, options) => ({
  target: 'node',
  entry: {
    rules: ['./src/adaptivity/rules.ts']
  },
  output: {
    path: path.resolve(__dirname, '../priv/node'),
    libraryTarget: 'commonjs2'
  },
  resolve: {
    extensions: ['.ts', '.js'],
    // Add webpack aliases for top level imports
    alias: {
      components: path.resolve(__dirname, 'src/components'),
      hooks: path.resolve(__dirname, 'src/hooks'),
      actions: path.resolve(__dirname, 'src/actions'),
      data: path.resolve(__dirname, 'src/data'),
      state: path.resolve(__dirname, 'src/state'),
      utils: path.resolve(__dirname, 'src/utils')
    }
  },
  module: {
    rules: [
      {
        test: /\.ts(x?)$/,
        include: path.resolve(__dirname, 'src'),
        use: [
          { loader: 'ts-loader', options: { configFile: 'tsconfig.node.json' } },
        ],
      }
    ],
  },
  plugins: [],
  watchOptions: {
    ignored: ['**/*.tsx', '**/node_modules', '**/*.scss'],
  }
});
