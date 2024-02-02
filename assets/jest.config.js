module.exports = {
  verbose: true,
  moduleDirectories: ['node_modules', 'src'],
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx'],
  moduleNameMapper: {
    '^phoenix/(.*)': '<rootDir>/src/phoenix/$1',
    '^components/(.*)': '<rootDir>/src/components/$1',
    '^state/(.*)': '<rootDir>/src/state/$1',
    '^editor/(.*)': '<rootDir>/src/editor/$1',
    '^utils/(.*)': '<rootDir>/src/utils/$1',
    '\\.[s]css': 'identity-obj-proxy',
    'monaco-editor': '<rootDir>/__mocks__/monaco.mock.js',

    /* react-markdown and rehype are esm modules that don't play nice with jest so we mock them out.
       this does mean you can't write tests for them, but currently we don't have any. */
    'react-markdown': '<rootDir>/__mocks__/react-markdown.mock.js',
    'rehype': '<rootDir>/__mocks__/react-markdown.mock.js',

    // necessary for jest to handle non-js file imports by mapping to an empty module
    '\\.(css|scss|wav)$': '<rootDir>/__mocks__/empty.mock.js',
  },
  transform: {
    '^.+\\.tsx?$': 'ts-jest',
  },
  transformIgnorePatterns: ['node_modules/(?!monaco-editor/.*)'],
  preset: 'ts-jest',
  globals: {
    'ts-jest': {
      babelConfig: 'babel.config.js',
    },
  },
  testRegex: 'test/.*_test.[jt]sx?$',
  collectCoverage: true,
  cacheDirectory: './node_modules/.cache/jest',
  setupFilesAfterEnv: ['<rootDir>/setup-tests.js'],
  testEnvironment: 'jest-environment-jsdom',
};
