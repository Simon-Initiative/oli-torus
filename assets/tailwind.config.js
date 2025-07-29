/* eslint-disable */
// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require('tailwindcss/plugin');
const tailwindFormsPlugin = require('@tailwindcss/forms');
const tailwindCSSVariablesPlugin = require('tailwind-css-variables');
const theme = require('./tailwind.theme.js');

module.exports = {
  content: [
    './src/**/*.{html,js,jsx,ts,tsx,mdx}',
    '../lib/oli/rendering/**/*.ex',
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex',
  ],
  darkMode: 'class',
  theme,
  plugins: [
    tailwindFormsPlugin,
    tailwindCSSVariablesPlugin({ oli: 'oli' }, {}),
    plugin(({ addVariant }) =>
      addVariant('phx-click-loading', ['&.phx-click-loading', '.phx-click-loading &']),
    ),
    plugin(({ addVariant }) =>
      addVariant('phx-submit-loading', ['&.phx-submit-loading', '.phx-submit-loading &']),
    ),
    plugin(({ addVariant }) =>
      addVariant('phx-change-loading', ['&.phx-change-loading', '.phx-change-loading &']),
    ),
    require('@tailwindcss/container-queries'),
  ],
  safelist: ['mb-24'],
};
