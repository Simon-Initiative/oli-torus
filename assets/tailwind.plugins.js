/* eslint-disable */
const plugin = require('tailwindcss/plugin');
const tokens = require('./tailwind.tokens');

const tokenColorPlugin = plugin(function ({ addComponents, addUtilities }) {
  const components = {};
  const utilities = {};

  Object.entries(tokens).forEach(([token, { light, dark }]) => {
    // Background
    components[`.bg-${token}`] = { backgroundColor: light };
    components[`.dark .bg-${token}`] = { backgroundColor: dark };

    // Text
    components[`.text-${token}`] = { color: light };
    components[`.dark .text-${token}`] = { color: dark };

    // Border
    components[`.border-${token}`] = { borderColor: light };
    components[`.dark .border-${token}`] = { borderColor: dark };

    // Outline
    components[`.outline-${token}`] = { outlineColor: light };
    components[`.dark .outline-${token}`] = { outlineColor: dark };

    // Ring
    components[`.ring-${token}`] = { '--tw-ring-color': light };
    components[`.dark .ring-${token}`] = { '--tw-ring-color': dark };

    // Fill
    components[`.fill-${token}`] = { fill: light };
    components[`.dark .fill-${token}`] = { fill: dark };

    // Stroke
    components[`.stroke-${token}`] = { stroke: light };
    components[`.dark .stroke-${token}`] = { stroke: dark };

    // Caret
    components[`.caret-${token}`] = { caretColor: light };
    components[`.dark .caret-${token}`] = { caretColor: dark };

    // Accent
    components[`.accent-${token}`] = { accentColor: light };
    components[`.dark .accent-${token}`] = { accentColor: dark };

    // Placeholder
    utilities[`.placeholder-${token}::placeholder`] = { color: light };
    utilities[`.dark .placeholder-${token}::placeholder`] = { color: dark };
  });

  addComponents(components);
  addUtilities(utilities, ['responsive', 'dark']);
});

module.exports = {
  tokenColorPlugin,
};
