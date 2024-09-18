// disjunction allows for both .300 and 300.
const regex = /^[+-]?((\d+\.?\d*)|(\.\d+))([eE][-+]?\d+)?$/;
export const isValidNumber = (value: string) => regex.test(value);
