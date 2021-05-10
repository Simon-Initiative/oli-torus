// TODO implement math engine

export const isExactlyMathOperator = (factValue: string, value: string) => {
  return factValue === value;
};

export const notExactlyMathOperator = (factValue: string, value: string) => {
  return factValue !== value;
};

export const isEquivalentOfMathOperator = (factValue: string, value: string) => {
  return factValue === value;
};

export const notIsEquivalentOfMathOperator = (factValue: string, value: string) => {
  return factValue !== value;
};

export const hasSameTermsMathOperator = (factValue: string, value: string) => {
  return factValue === value;
};
export const hasDifferentTermsMathOperator = (factValue: string, value: string) => {
  return factValue !== value;
};

const operators = {
  isExactly: isExactlyMathOperator,
  notIsExactly: notExactlyMathOperator,
  isEquivalentOf: isEquivalentOfMathOperator,
  notIsEquivalentOf: notIsEquivalentOfMathOperator,
  hasSameTerms: hasSameTermsMathOperator,
  hasDifferentTerms: hasDifferentTermsMathOperator,
};

export default operators;
