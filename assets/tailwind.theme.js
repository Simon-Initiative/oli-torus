/* eslint-disable */
const colors = require('tailwindcss/colors')

module.exports = {
  extend: {
    colors: {
      primary: colors.blue['500'],
      secondary: colors.gray['600'],
      danger: '#e74c3c',
      warning: '#f39c12',
      info: '#3498db',
      selection: '#2c67c4',
      hover: colors.blue['600'],
      light: colors.blue['700'],
      'body-bg': colors.white,
      'body-color': colors.gray['900'],
      'choice-selected-bg': colors.blue['400'],
      'choice-selected-bg-hover': colors.blue['300'],
      'choice-selected-border-color': colors.blue['500'],
      'choice-selected-color': colors.blue['500'],
      'feedback-correct-bg': colors.green['200'],
      'feedback-correct-color': colors.black,
      'feedback-correct-graphic-color': colors.green['500'],
      'feedback-error-bg': colors.orange['200'],
      'feedback-error-color': colors.black,
      'feedback-explanation-bg': colors.blue['200'],
      'feedback-explanation-color': colors.black,
      'feedback-explanation-graphic-color': colors.blue['500'],
      'feedback-incorrect-bg': colors.red['200'],
      'feedback-incorrect-color': colors.black,
      'feedback-incorrect-graphic-color': colors.red['500'],
      'feedback-partially-correct-bg': colors.yellow['200'],
      'feedback-partially-correct-color': colors.black,
      'feedback-partially-correct-graphic-color': colors.yellow['500'],
      'hints-bg': colors.gray['200'],
      'hints-border': colors.gray['500'],
      'hints-color': colors.black,
    },
    forms: {
      borderRadius: 4,
    },
  },
};
