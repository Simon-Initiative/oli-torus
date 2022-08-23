/* eslint-disable */
const path = require('path');
const glob = require('glob');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const { ESBuildMinifyPlugin } = require('esbuild-loader');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const MonacoWebpackPlugin = require('monaco-editor-webpack-plugin');

const MONACO_DIR = path.resolve(__dirname, './node_modules/monaco-editor');
const SHADOW_DOM_ENABLED = [path.resolve(__dirname, './src/components/parts/janus-fill-blanks')];

// Determines the entry points for the webpack by looking at activity
// implementations in src/components/activities folder
const populateEntries = () => {
  // These are the non-activity bundles
  const initialEntries = {
    app: ['babel-polyfill', './src/phoenix/app.ts'],
    components: ['./src/apps/Components.tsx'],
    pageeditor: ['./src/apps/PageEditorApp.tsx'],
    activitybank: ['./src/apps/ActivityBankApp.tsx'],
    bibliography: ['./src/apps/BibliographyApp.tsx'],
    authoring: ['./src/apps/AuthoringApp.tsx'],
    delivery: ['./src/apps/DeliveryApp.tsx'],
    stripeclient: ['./src/payment/stripe/client.ts'],
    timezone: ['./src/phoenix/timezone.ts'],
    dark: ['./src/phoenix/dark.ts'],
    keepalive: ['./src/phoenix/keep-alive.ts'],
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
      .sync('./styles/themes/authoring/*.scss')
      .map((p) => ({ prefix: 'authoring_', themePath: p })),
    ...glob
      .sync('./styles/themes/authoring/custom/*.scss')
      .map((p) => ({ prefix: 'authoring_', themePath: p })),
    ...glob
      .sync('./styles/themes/delivery/*.scss')
      .map((p) => ({ prefix: 'delivery_', themePath: p })),
    ...glob
      .sync('./styles/themes/delivery/custom/*.scss')
      .map((p) => ({ prefix: 'delivery_', themePath: p })),
    ...glob
      .sync('./styles/themes/delivery/adaptive_themes/*/light.scss')
      .map((p) => ({ prefix: 'delivery_adaptive_themes_default_', themePath: p })),
    ...glob
      .sync('./styles/themes/preview/*.scss')
      .map((p) => ({ prefix: 'preview_', themePath: p })),
  ];

  const foundThemes = themePaths.map(({ prefix, themePath }) => {
    const theme = path.basename(themePath, '.scss');

    return {
      [prefix + theme]: themePath,
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
  externals: {
    react: {
      root: 'React',
      commonjs2: 'react',
      commonjs: 'react',
      amd: 'react',
    },
    'react-dom': {
      root: 'ReactDOM',
      commonjs2: 'react-dom',
      commonjs: 'react-dom',
      amd: 'react-dom',
    },
  },
  devtool: 'source-map',
  optimization: {
    minimize: process.env.NODE_ENV == 'production',
    minimizer: [new ESBuildMinifyPlugin({ css: true })],
  },
  entry: populateEntries(),
  output: {
    path: path.resolve(__dirname, '../priv/static/js'),
    libraryTarget: 'umd',
  },
  resolve: {
    extensions: ['.ts', '.tsx', '.js', '.jsx', '.scss', '.css', '.ttf'],
    // Add webpack aliases for top level imports
    alias: {
      components: path.resolve(__dirname, 'src/components'),
      hooks: path.resolve(__dirname, 'src/hooks'),
      actions: path.resolve(__dirname, 'src/actions'),
      data: path.resolve(__dirname, 'src/data'),
      state: path.resolve(__dirname, 'src/state'),
      utils: path.resolve(__dirname, 'src/utils'),
      styles: path.resolve(__dirname, 'styles'),
      apps: path.resolve(__dirname, 'src/apps'),
      adaptivity: path.resolve(__dirname, 'src/adaptivity'),
    },
    fallback: { vm: require.resolve('vm-browserify') },
  },
  module: {
    rules: [
      {
        test: /\.js(x?)$/,
        include: path.resolve(__dirname, 'src'),
        use: {
          loader: 'esbuild-loader',
          options: {
            loader: 'jsx',
          },
        },
      },
      {
        test: /\.ts(x?)$/,
        include: path.resolve(__dirname, 'src'),
        use: [
          {
            loader: 'esbuild-loader',
            options: {
              loader: 'tsx',
            },
          },
        ],
      },
      {
        test: /\.css$/,
        include: MONACO_DIR,
        use: ['style-loader', 'css-loader'],
      },
      {
        test: /\.ttf$/,
        include: MONACO_DIR,
        use: ['file-loader'],
      },
      // load fonts, specifically for MathLive
      {
        test: /\.(woff(2)?|ttf|eot|svg)(\?v=\d+\.\d+\.\d+)?$/,
        use: [
          {
            loader: 'file-loader',
            options: {
              name: '[name].[ext]',
              outputPath: 'fonts/',
            },
          },
        ],
      },
      // load sounds, specifically for MathLive
      {
        test: /\.wav$/,
        use: [
          {
            loader: 'file-loader',
            options: {
              name: '[name].[ext]',
              outputPath: 'sounds/',
            },
          },
        ],
      },
      {
        test: /\.[s]?css$/,
        include: SHADOW_DOM_ENABLED,
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
                includePaths: [path.join(__dirname, 'styles')],
                quietDeps: true,
              },
              sourceMap: true,
            },
          },
        ],
      },
      {
        test: /\.[s]?css$/,
        include: path.resolve(__dirname, 'src'),
        exclude: SHADOW_DOM_ENABLED,
        use: [
          'style-loader',
          {
            loader: 'css-loader',
            options: {
              modules: {
                mode: 'local',
                auto: true,
                localIdentName: '[local]_[hash:base64:8]',
              },
              sourceMap: true,
            },
          },
          {
            loader: 'sass-loader',
            options: {
              sassOptions: {
                includePaths: [path.join(__dirname, 'styles')],
                quietDeps: true,
              },
              sourceMap: true,
            },
          },
        ],
      },
      {
        test: /\.[s]?css$/,
        exclude: [MONACO_DIR, path.resolve(__dirname, 'src')],
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
                includePaths: [path.join(__dirname, 'styles')],
                quietDeps: true,
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
    new MiniCssExtractPlugin({
      filename: '../css/[name].css',
    }),
    new CopyWebpackPlugin({ patterns: [{ from: 'static/', to: '../' }] }),
    new MonacoWebpackPlugin(),
  ],
});
