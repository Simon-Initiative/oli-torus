/* eslint-env node */
/* eslint-disable @typescript-eslint/no-var-requires */
const evalEngine = require('./eval.js');

exports.handler = async function (event, context) {
  return evalEngine.handler(event, context);
};
