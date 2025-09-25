/* eslint-disable */
// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require('tailwindcss/plugin');
const tailwindFormsPlugin = require('@tailwindcss/forms');
const tailwindCSSVariablesPlugin = require('tailwind-css-variables');
const theme = require('./tailwind.theme.js');
const { tokenColorPlugin } = require('./tailwind.plugins');

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
    tokenColorPlugin,
    tailwindFormsPlugin,
    tailwindCSSVariablesPlugin({ oli: 'oli' }, {}),
    plugin(({ addVariant }) =>
      addVariant('phx-no-feedback', ['&.phx-no-feedback', '.phx-no-feedback &']),
    ),
    plugin(({ addVariant }) =>
      addVariant('phx-click-loading', ['&.phx-click-loading', '.phx-click-loading &']),
    ),
    plugin(({ addVariant }) =>
      addVariant('phx-submit-loading', ['&.phx-submit-loading', '.phx-submit-loading &']),
    ),
    plugin(({ addVariant }) =>
      addVariant('phx-change-loading', ['&.phx-change-loading', '.phx-change-loading &']),
    ),

    // example:<button data-selected={"#{@active_tab == "activities"}"} class="selected:text-white not-selected:text-black">...</button>
    plugin(({ addVariant }) => addVariant('selected', '&[data-selected="true"]')),
    plugin(({ addVariant }) => addVariant('not-selected', '&[data-selected="false"]')),
    require('@tailwindcss/container-queries'),
  ],
  safelist: ['mb-24'],
};
