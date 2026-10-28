require('@testing-library/jest-dom');
require('@testing-library/react');
require('regenerator-runtime/runtime');

const timers = require('timers');

global.setImmediate = timers.setImmediate;
global.clearImmediate = timers.clearImmediate;
