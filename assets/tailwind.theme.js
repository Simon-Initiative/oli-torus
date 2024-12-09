/* eslint-disable */
const tailwindColors = require('tailwindcss/colors');

/**
 * Extend the default tailwind color palette by overriding specific colors.
 *
 * More colors can be added or overridden. Useful utility for generating a
 * palette of shades for a specific color: https://www.tailwindshades.com/
 */
const colors = {
  ...tailwindColors,
  gray: {
    ...tailwindColors.neutral,
    850: '#1E1E1E',
  },
  blue: {
    DEFAULT: '#3B76D3',
    50: '#D1DFF5',
    100: '#C1D3F1',
    200: '#9FBCE9',
    300: '#7EA5E2',
    400: '#5D8DDB',
    500: '#3B76D3',
    600: '#275CAF',
    700: '#1D4481',
    800: '#132C53',
    900: '#081425',
  },
  yellow: {
    DEFAULT: '#F7AE32',
    50: '#FEF4E3',
    100: '#FDECCF',
    200: '#FCDDA8',
    300: '#FACD81',
    400: '#F9BE59',
    500: '#F7AE32',
    600: '#E89509',
    700: '#B27307',
    800: '#7C5005',
    900: '#462D03',
  },
  // new colors from UX audit 11.2023
  offWhite: '#E8E8E8',
  offBlack: '#373A44',
  azure: {
    50: '#D1DFF5',
    100: '#E9F4FF',
    200: '#CEE7FF',
    300: '#A1D2FF',
    400: '#69B0FB',
    500: '#2B8BFE',
    600: '#0165D9',
    700: '#004A9F',
    800: '#002E72',
    900: '#071538',
  },
};

module.exports = {
  colors: {
    ...colors,
    primary: {
      DEFAULT: colors.blue['500'],
      ...colors.blue,
    },
    secondary: colors.gray['600'],
    danger: '#e74c3c',
    warning: '#f39c12',
    info: '#3498db',
    selection: '#2c67c4',
    hover: colors.blue['600'],
    light: colors.gray['300'],
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
        // DEFAULT: '#1E1E1E',
        DEFAULT: '#2a2b2e',
        50: '#B7B7B7',
        100: '#ADADAD',
        200: '#989898',
        300: '#848484',
        400: '#707070',
        500: '#5B5B5B',
        600: '#474747',
        700: '#323232',
        800: '#1E1E1E',
        900: '#020202',
      },
    },
    'body-color': {
      DEFAULT: '#373A44',
      dark: {
        DEFAULT: '#f5f5f5',
      },
    },
    workspace: {
      header: {
        bg: {
          DEFAULT: '#f5f8fb',
          dark: {
            DEFAULT: '#3e3f44;',
          },
        },
      },
      breadcrumb: {
        bg: {
          DEFAULT: '',
          dark: {
            DEFAULT: '#3e3f44',
          },
        },
      },
      sidebar: {
        bg: {
          DEFAULT: '#e3e7ec',
          dark: {
            DEFAULT: '#3e3f44',
          },
        },
      },
      footer: {
        bg: {
          DEFAULT: 'transparent',
          dark: {
            DEFAULT: 'transparent',
          },
        },
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
    'feedback-table-color': colors.black,
    toolbar: {
      bg: {
        DEFAULT: '#f8f9fb',
        dark: {
          DEFAULT: '#3e3f44',
        },
      },
      border: {
        DEFAULT: '#e5e6e8',
        dark: {
          DEFAULT: '#55565d',
        },
      },
    },
    delivery: {
      body: {
        DEFAULT: '#f3f5f8',
        dark: {
          DEFAULT: '#0D0C0F',
        },
      },
      'body-color': {
        DEFAULT: '#373A44',
        dark: {
          DEFAULT: colors.white,
        },
      },
      header: {
        DEFAULT: '#ffffff',
        dark: {
          DEFAULT: '#000000',
        },
      },
      navbar: {
        DEFAULT: '#ffffff',
        dark: {
          DEFAULT: '#000000',
        },
      },
      primary: {
        DEFAULT: colors.azure['600'],
        active: colors.azure['700'],
        hover: colors.azure['700'],
        dark: {
          DEFAULT: colors.azure['500'],
          active: colors.azure['400'],
          hover: colors.azure['400'],
        },
        ...colors.azure,
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
            DEFAULT: '#ddd',
            dark: {
              DEFAULT: '#404040',
            },
          },
        },
      },
      'instructor-dashboard': {
        footer: {
          DEFAULT: '#eceef1',
          dark: {
            DEFAULT: '#323233',
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
      },
      tooltip: {
        bg: {
          DEFAULT: colors.offBlack,
          dark: colors.offWhite,
        },
        content: {
          DEFAULT: colors.white,
          dark: colors.black,
        },
      },
    },
    google: {
      'text-gray': '#3c4043',
      'button-blue': '#1a73e8',
      'button-blue-hover': '#5195ee',
      'button-dark': '#202124',
      'button-dark-hover': '#555658',
      'button-border-light': '#dadce0',
      'logo-blue': '#4285f4',
      'logo-green': '#34a853',
      'logo-yellow': '#fbbc05',
      'logo-red': '#ea4335',
    },
  },
  extend: {
    fontFamily: {
      sans: ['Open Sans', 'sans-serif'],
    },
    fontSize: {
      xs: '0.8rem',
    },
    forms: {
      borderRadius: 4,
    },
    keyframes: {
      'slide-in-right': {
        '0%': {
          transform: 'translateX(100%)',
        },
        '100%': {
          transform: 'translateX(0)',
        },
      },
      shimmer: {
        '100%': {
          transform: 'translateX(100%)',
        },
      },
    },
    animation: {
      'slide-in-right': {
        'slide-in-right': 'slide-in-right 0.5s ease-out',
      },
    },
    screens: {
      // horizontal breakpoints
      sm: '640px',
      // => @media (min-width: 640px) { ... }
      md: '768px',
      // => @media (min-width: 768px) { ... }
      lg: '1024px',
      // => @media (min-width: 1024px) { ... }
      xl: '1280px',
      // => @media (min-width: 1280px) { ... }
      '2xl': '1536px',
      // => @media (min-width: 1536px) { ... }

      // vertical breakpoints
      vsm: { raw: '(min-height: 350px)' },
      vmd: { raw: '(min-height: 500px)' },
      vlg: { raw: '(min-height: 650px)' },
      vxl: { raw: '(min-height: 800px)' },
      v2xl: { raw: '(min-height: 950px)' },

      // horizontal-vertical breakpoints (triggered when the horizontal or vertical conditions are met)
      hvsm: { raw: '(min-width: 640px) and (min-height: 350px)' },
      hvmd: { raw: '(min-width: 768px) and (min-height: 500px)' },
      hvlg: { raw: '(min-width: 1024px) and (min-height: 650px)' },
      hvxl: { raw: '(min-width: 1280px) and (min-height: 800px)' },
      hv2xl: { raw: '(min-width: 1536px) and (min-height: 950px)' },
    },
    colors: {
      'high-24': { DEFAULT: '#EEEBF5' },
      'primary-24': { DEFAULT: '#0D0C0F' },
      checkpoint: {
        DEFAULT: '#B27307',
        dark: '#FF8F40',
      },
      practice: { DEFAULT: '#1D4ED8', dark: '#8CBCFF' },
      exploration: { DEFAULT: '#A21CAF', dark: '#EC8CFF' },
    },
  },
};
