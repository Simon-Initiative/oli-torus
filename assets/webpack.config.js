const webpack = require('webpack');
const path = require('path');
const glob = require('glob');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const UglifyJsPlugin = require('uglifyjs-webpack-plugin');
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');

// Determines the entry points for the webpack by looking at activity
// implementations in src/components/activities folder
const populateEntries = () => {

  // These are the non-activity bundles
  const initialEntries = {
    app: ['./src/phoenix/app.ts'],
    components: ['./src/components.tsx'],
    resourceeditor: ['./src/components/resource/ResourceEditorApp.tsx'],
    activityeditor: ['./src/components/activity/ActivityEditorApp.tsx'],
  };

  const manifests = glob.sync("./src/components/activities/*/manifest.json", {});

  const foundActivities = manifests.map((manifestPath) => {
    const manifest = require(manifestPath);
    const rootPath = manifestPath.substr(0, manifestPath.indexOf('manifest.json'));
    return {
      [manifest.id + '_authoring']: [rootPath + manifest.authoring.entry],
      [manifest.id + '_delivery']: [rootPath + manifest.delivery.entry],
    };
  });

  // Merge the attributes of all found activities and the initialEntries
  // into one single object.
  const merged = foundActivities.reduce((p, c) => Object.assign({}, p, c), initialEntries);

  // Validate: We should have (2 * foundActivities.length) + number of keys in initialEntries
  // If we don't it is likely due to a naming collision in two or more manifests
  if (Object.keys(merged).length != Object.keys(initialEntries).length + (2 * foundActivities.length)) {
    throw new Error('Encountered a possible naming collision in activity manifests. Aborting.');
  }

  return merged;
};

module.exports = (env, options) => ({
  optimization: {
    chunkIds: "named",
		splitChunks: {
			cacheGroups: {
				vendor: {
					test: /node_modules/,
					chunks: "initial",
					name: "vendor",
					priority: 10,
					enforce: true
				}
			}
		},
    minimizer: [
      new UglifyJsPlugin({ cache: true, parallel: true, sourceMap: true }),
      new OptimizeCSSAssetsPlugin({})
    ]
  },
  entry: populateEntries(),
  output: {
    filename: '[name].js',
    path: path.resolve(__dirname, '../priv/static/js')
  },
  resolve: {
    extensions: ['.ts', '.tsx', '.js', '.jsx'],
    // Add webpack aliases for top level imports
    alias: {
      components: path.resolve(__dirname, 'src/components'),
      hooks: path.resolve(__dirname, 'src/hooks'),
      actions: path.resolve(__dirname, 'src/actions'),
      data: path.resolve(__dirname, 'src/data'),
      state: path.resolve(__dirname, 'src/state'),
      utils: path.resolve(__dirname, 'src/utils'),
      stylesheets: path.resolve(__dirname, 'src/stylesheets'),
    },
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader'
        }
      },
      {
        test: /\.[s]?css$/,
        use: [
          MiniCssExtractPlugin.loader,
          {
            loader: 'css-loader'
          },
          {
              loader: 'sass-loader',
              options: {
                sassOptions: {
                  includePaths: [
                      path.join(__dirname, 'src/stylesheets'),
                  ],
                },
                sourceMap: true
              }
          }
        ],
      },
      {
        test: /\.jsx$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader'
        }
      },
      { test: /\.(png|gif|jpg|jpeg|svg)$/, use: 'file-loader' },
      { test: /\.ts$/, use: ['babel-loader', 'ts-loader'], exclude: /node_modules/ },
      {
        test: /\.tsx$/, use: [
          {
            loader: 'babel-loader',
            options: {
              // This is a feature of `babel-loader` for webpack (not Babel itself).
              // It enables caching results in ./node_modules/.cache/babel-loader/
              // directory for faster rebuilds.
              cacheDirectory: true
            },
          },
          { loader: 'ts-loader' }
        ], exclude: /node_modules/
      }
    ]
  },
  plugins: [
    new webpack.ProvidePlugin({
      React: 'react',
    }),
    new MiniCssExtractPlugin({ filename: '../css/[name].css' }),
    new CopyWebpackPlugin([{ from: 'static/', to: '../' }]),
  ]
});
