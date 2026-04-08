const evalEngine = require('./eval.js');

exports.handler = async function (event, context) {
  return evalEngine.handler(event, context);
};
