module.exports = {
  verbose: true,
  moduleDirectories: [
    "node_modules",
    "src",
  ],
  moduleFileExtensions: [
    "ts",
    "tsx",
    "js"
  ],
  moduleNameMapper: {
    "^components/(.*)": "<rootDir>/src/components/$1",
    "^state/(.*)": "<rootDir>/src/state/$1",
    "^editor/(.*)": "<rootDir>/src/editor/$1",
    "^utils/(.*)": "<rootDir>/src/utils/$1",
  },
  transform: {
    ".*": "<rootDir>/jest.preprocessor.js"
  },
  testRegex: "test/.*\.test\.(ts|tsx|js)$",
  collectCoverage: true,
  testResultsProcessor: "./node_modules/jest-html-reporter",
  cacheDirectory: "./node_modules/.cache/jest",
  reporters: [
    "default",
    ["./node_modules/jest-html-reporter", {
        pageTitle: "Test Report",
        outputPath: "./test-results/results.html"
    }]
]
};