/* eslint-disable */
const colors = require('tailwindcss/colors');

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
      body: {
        DEFAULT: colors.white,
        50: '#f9f9f9',
        100: '#f2f2f2',
        200: '#d9d9d9',
        300: '#bfbfbf',
        400: '#a6a6a6',
        500: '#8c8c8c',
        600: '#737373',
        700: '#595959',
        800: '#404040',
        900: '#262626',
        dark: {
          DEFAULT: colors.gray['900'],
          50: '#262626',
          100: '#404040',
          200: '#595959',
          300: '#737373',
          400: '#8c8c8c',
          500: '#a6a6a6',
          600: '#bfbfbf',
          700: '#d9d9d9',
          800: '#f2f2f2',
          900: '#f9f9f9',
        },
      },
      'body-color': {
        DEFAULT: '#373A44',
        dark: {
          DEFAULT: colors.white,
        },
      },
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
      delivery: {
        body: {
          DEFAULT: '#f3f5f8',
          dark: {
            DEFAULT: colors.gray['900'],
          },
        },
        'body-color': {
          DEFAULT: '#373A44',
          dark: {
            DEFAULT: colors.white,
          },
        },
        footer: {
          DEFAULT: '#eceef1',
          dark: {
            DEFAULT: '#222439',
          },
        },
        header: {
          DEFAULT: '#222439',
          600: '#52526b',
          700: '#3b3b4d',
          800: '#2a2a3e',
          dark: {
            DEFAULT: '#222439',
          },
        },
        primary: {
          DEFAULT: '#5B1EEA',
          50: '#eee8fd',
          100: '#ccb9f8',
          200: '#aa8af4',
          300: '#885cf0',
          400: '#662deb',
          500: '#5B1EEA',
          600: '#4d14d2',
          700: '#3c0fa3',
          800: '#2b0b75',
          900: '#1a0746',
        },
        hints: {
          bg: {
            DEFAULT: colors.gray['100'],
            dark: {
              DEFAULT: colors.gray['700'],
            },
          },
          border: {
            DEFAULT: colors.gray['200'],
            dark: {
              DEFAULT: colors.gray['600'],
            },
          },
        },
        purpose: {
          label: {
            bg: {
              DEFAULT: '#222439',
              dark: {
                DEFAULT: '#2f3d52',
              },
            },
          },
        },
      },
    },
    fontFamily: {
      sans: ['Open Sans', 'sans-serif'],
    },
    fontSize: {
      xs: '0.8rem',
    },
    forms: {
      borderRadius: 4,
    },
    extend: {
      keyframes: {
        'slide-in-right': {
          '0%': {
            transform: 'translateX(100%)',
          },
          '100%': {
            transform: 'translateX(0)',
          },
        },
      },
      animation: {
        'slide-in-right': {
          'slide-in-right': 'slide-in-right 0.5s ease-out',
        },
      },
    },
  },
};
