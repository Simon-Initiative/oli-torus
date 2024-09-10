/* eslint-disable */
const path = require('path');
const glob = require('glob');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const { ESBuildMinifyPlugin } = require('esbuild-loader');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const MonacoWebpackPlugin = require('monaco-editor-webpack-plugin');
const LicensePlugin = require('webpack-license-plugin');

const BundleAnalyzerPlugin = require('webpack-bundle-analyzer').BundleAnalyzerPlugin;

const MONACO_DIR = path.resolve(__dirname, './node_modules/monaco-editor');
const SHADOW_DOM_ENABLED = [path.resolve(__dirname, './src/components/parts/janus-fill-blanks')];

const BUNDLE_ANALYZER_ENABLED = process.env.BUNDLE_ANALYZER_ENABLED === 'true';

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
    scheduler: ['./src/apps/SchedulerApp.tsx'],
    stripeclient: ['./src/payment/stripe/client.ts'],
    cashnetclient: ['./src/payment/cashnet/client.ts'],
    timezone: ['./src/phoenix/timezone.ts'],
    dark: ['./src/phoenix/dark.ts'],
    keepalive: ['./src/phoenix/keep-alive.ts'],
    delivery_adaptive_themes_default_light: ['./styles/adaptive/light.scss'],
    delivery_adaptive_themes_flowchart: ['./styles/adaptive/flowchart.scss'],
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

  const styleSheets = [
    { adaptive: './styles/adaptive/adaptive-reset.scss' },
    { styles: './styles/index.scss' },
    { preview: './styles/preview.scss' },
  ];

  // Merge the attributes of all found activities and the initialEntries
  // into one single object.
  const merged = [...foundActivities, ...foundParts, ...styleSheets].reduce(
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
    styleSheets.length
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
    minimize: options.mode == 'production',
    minimizer: [new ESBuildMinifyPlugin({ css: true })],
    sideEffects: true,
    splitChunks: {
      chunks: 'async',
      cacheGroups: {
        vendor: {
          /* Goal of this chunk is to get all our node_modules shared code into a single vendor.js chunk that any entry point can use.
             It's going to be bigger than any single entry needs, but having a single one will allow them all to share the same emitted
             code. A future improvement might be to split this into an authoring and a delivery chunk, but that gets complicated quick.
             */
          test: /([\\/]node_modules[\\/])/,
          name: 'vendor',
          chunks: 'all',
        },
      },
    },
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
    fallback: {
      vm: require.resolve('vm-browserify'),
      'react/jsx-runtime': 'react/jsx-runtime.js',
      'react/jsx-dev-runtime': 'react/jsx-dev-runtime.js',
    },
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
        use: [
          {
            loader: 'file-loader',
            options: {
              outputPath: 'fonts/',
              publicPath: '/js/fonts',
            },
          },
        ],
      },
      // load fonts, specifically for MathLive
      {
        test: /\.(woff(2)?|ttf|eot|svg)(\?v=\d+\.\d+\.\d+)?$/,
        exclude: MONACO_DIR,
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
              sourceMap: options.mode !== 'production',
            },
          },
          {
            loader: 'sass-loader',
            options: {
              sassOptions: {
                includePaths: [path.join(__dirname, 'styles')],
                quietDeps: true,
              },
              sourceMap: options.mode !== 'production',
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
              sourceMap: options.mode !== 'production',
            },
          },
          {
            loader: 'sass-loader',
            options: {
              sassOptions: {
                includePaths: [path.join(__dirname, 'styles')],
                quietDeps: true,
              },
              sourceMap: options.mode !== 'production',
            },
          },
        ],
      },
      {
        // This one EXCLUDES monaco & src, so it includes things like css inside node_modules
        test: /\.[s]?css$/,
        exclude: [MONACO_DIR, path.resolve(__dirname, 'src')],
        use: [
          MiniCssExtractPlugin.loader,
          {
            loader: 'css-loader',
            options: {
              sourceMap: options.mode !== 'production',
            },
          },
          {
            loader: 'sass-loader',
            options: {
              sassOptions: {
                includePaths: [path.join(__dirname, 'styles')],
                quietDeps: true,
              },
              sourceMap: options.mode !== 'production',
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
    BUNDLE_ANALYZER_ENABLED ? new BundleAnalyzerPlugin() : undefined,
    new MiniCssExtractPlugin({
      filename: '../css/[name].css',
    }),
    new CopyWebpackPlugin({
      patterns: [
        {
          from: 'static/',
          to: '../',
          filter: async (path) => path.indexOf('.map') == -1, // these were causing a duplicate file error on a production build
        },
      ],
    }),
    new MonacoWebpackPlugin(),
    new LicensePlugin({
      outputFilename: '../licenses.json',
      licenseOverrides: {
        'janus-script@1.9.2': 'MIT',
        'phoenix_html@3.3.1': 'MIT',
        'phoenix_html@3.3.2': 'MIT',
        'phoenix_html@3.3.3': 'MIT',
        'phoenix_html@3.3.4': 'MIT',
        'typed-function@2.0.0': 'MIT',
      },
      unacceptableLicenseTest: (licenseIdentifier) => {
        // unacceptable licenses
        return ['GPL', 'AGPL', 'LGPL', 'NGPL'].includes(licenseIdentifier);
      },
    }),
  ].filter((plugin) => plugin !== undefined),
});
