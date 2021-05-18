/* eslint-disable */
const webpack = require('webpack');
const path = require('path');
const glob = require('glob');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const globImporter = require('node-sass-glob-importer');
const UglifyJsPlugin = require('uglifyjs-webpack-plugin');
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');

// Determines the entry points for the webpack by looking at activity
// implementations in src/components/activities folder
const populateEntries = () => {
  // These are the non-activity bundles
  const initialEntries = {
    app: ['babel-polyfill', './src/phoenix/app.ts'],
    components: ['./src/components.tsx'],
    resourceeditor: ['./src/components/resource/ResourceEditorApp.tsx'],
    activityeditor: ['./src/components/activity/ActivityEditorApp.tsx'],
    authoring: ['./src/apps/AuthoringApp.tsx'],
    delivery: ['./src/apps/DeliveryApp.tsx']
  };

  const manifests = glob.sync('./src/components/activities/*/manifest.json', {});

  const foundActivities = manifests.map((manifestPath) => {
    const manifest = require(manifestPath);
    const rootPath = manifestPath.substr(0, manifestPath.indexOf('manifest.json'));
    return {
      [manifest.id + '_authoring']: [rootPath + manifest.authoring.entry],
      [manifest.id + '_delivery']: [rootPath + manifest.delivery.entry],
    };
  });

  const partComponentManifests = glob.sync('./src/components/parts/*/manifest.json', {});
  const foundParts = partComponentManifests.map((partComponentManifestPath) => {
    const manifest = require(partComponentManifestPath);
    const rootPath = partComponentManifestPath.substr(
      0,
      partComponentManifestPath.indexOf('manifest.json'),
    );
    return {
      [manifest.id + '_authoring']: [rootPath + manifest.authoring.entry],
      [manifest.id + '_delivery']: [rootPath + manifest.delivery.entry],
    };
  });

  const themePaths = [
    ...glob
      .sync('./styles/themes/authoring/*/light.scss')
      .map((p) => ({ prefix: 'authoring_', themePath: p })),
    ...glob
      .sync('./styles/themes/authoring/*/dark.scss')
      .map((p) => ({ prefix: 'authoring_', themePath: p })),
    ...glob
      .sync('./styles/themes/delivery/*/light.scss')
      .map((p) => ({ prefix: 'delivery_', themePath: p })),
    ...glob
      .sync('./styles/themes/delivery/*/dark.scss')
      .map((p) => ({ prefix: 'delivery_', themePath: p })),
    ...glob
      .sync('./styles/themes/preview/*/light.scss')
      .map((p) => ({ prefix: 'preview_', themePath: p })),
    ...glob
      .sync('./styles/themes/preview/*/dark.scss')
      .map((p) => ({ prefix: 'preview_', themePath: p })),
  ];

  const foundThemes = themePaths.map(({ prefix, themePath }) => {
    const theme = path.basename(path.dirname(themePath));
    const colorScheme = path.basename(themePath, '.scss');

    return {
      [prefix + theme + '_' + colorScheme]: themePath,
    };
  });

  // Merge the attributes of all found activities and the initialEntries
  // into one single object.
  const merged = [...foundActivities, ...foundParts, ...foundThemes].reduce(
    (p, c) => Object.assign({}, p, c),
    initialEntries,
  );

  // Validate: We should have (2 * foundActivities.length) + number of keys in initialEntries
  // If we don't it is likely due to a naming collision in two or more manifests
  if (
    Object.keys(merged).length !=
    Object.keys(initialEntries).length +
      2 * foundActivities.length +
      2 * foundParts.length +
      foundThemes.length
  ) {
    throw new Error(
      'Encountered a possible naming collision in activity or part manifests. Aborting.',
    );
  }

  return merged;
};

module.exports = (env, options) => ({
  devtool: 'source-map',
  optimization: {
    minimizer: [
      new UglifyJsPlugin({ cache: true, parallel: true, sourceMap: true }),
      new OptimizeCSSAssetsPlugin({}),
    ],
  },
  entry: populateEntries(),
  output: {
    path: path.resolve(__dirname, '../priv/static/js'),
  },
  resolve: {
    extensions: ['.ts', '.tsx', '.js', '.jsx', '.scss'],
    // Add webpack aliases for top level imports
    alias: {
      components: path.resolve(__dirname, 'src/components'),
      hooks: path.resolve(__dirname, 'src/hooks'),
      actions: path.resolve(__dirname, 'src/actions'),
      data: path.resolve(__dirname, 'src/data'),
      state: path.resolve(__dirname, 'src/state'),
      utils: path.resolve(__dirname, 'src/utils'),
      styles: path.resolve(__dirname, 'styles'),
    },
    fallback: { "vm": require.resolve("vm-browserify") }
  },
  module: {
    rules: [
      {
        test: /\.js(x?)$/,
        include: path.resolve(__dirname, 'src'),
        use: {
          loader: 'babel-loader',
          options: {
            cache: true,
          },
        },
      },
      {
        test: /\.ts(x?)$/,
        include: path.resolve(__dirname, 'src'),
        use: [
          {
            loader: 'babel-loader',
            options: {
              cacheDirectory: true,
            },
          },
          { loader: 'ts-loader' },
        ],
      },
      {
        test: /\.[s]?css$/,
        use: [
          MiniCssExtractPlugin.loader,
          {
            loader: 'css-loader',
            options: {
              sourceMap: true,
            },
          },
          {
            loader: 'sass-loader',
            options: {
              sassOptions: {
                includePaths: [path.join(__dirname, 'src'), path.join(__dirname, 'styles')],
                importer: globImporter(),
              },
              sourceMap: true,
            },
          },
        ],
      },
      {
        test: /\.(png|gif|jpg|jpeg|svg)$/,
        type: 'asset/resource',
      },
    ],
  },
  plugins: [
    new webpack.ProvidePlugin({
      React: 'react',
    }),
    new MiniCssExtractPlugin({ filename: '../css/[name].css' }),
    new CopyWebpackPlugin({ patterns: [{ from: 'static/', to: '../' }] })
  ],
});
