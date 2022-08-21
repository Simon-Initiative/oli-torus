module.exports = {
  verbose: true,
  moduleDirectories: ['node_modules', 'src'],
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx'],
  moduleNameMapper: {
    '^components/(.*)': '<rootDir>/src/components/$1',
    '^state/(.*)': '<rootDir>/src/state/$1',
    '^editor/(.*)': '<rootDir>/src/editor/$1',
    '^utils/(.*)': '<rootDir>/src/utils/$1',
    '\\.[s]css': 'identity-obj-proxy',
    'monaco-editor': '<rootDir>/__mocks__/monaco.mock.js',
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
