// TODO implement math engine
export const isExactlyMathOperator = (factValue, value) => {
    return factValue === value;
};
export const notExactlyMathOperator = (factValue, value) => {
    return factValue !== value;
};
export const isEquivalentOfMathOperator = (factValue, value) => {
    return factValue === value;
};
export const notIsEquivalentOfMathOperator = (factValue, value) => {
    return factValue !== value;
};
export const hasSameTermsMathOperator = (factValue, value) => {
    return factValue === value;
};
export const hasDifferentTermsMathOperator = (factValue, value) => {
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
//# sourceMappingURL=math.js.map