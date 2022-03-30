import { isNumber, parseArray } from 'utils/common';

export const inRangeOperator = (factValue: any, value: any): boolean => {
  const typeOfFactValue = typeof factValue;
  //the rules that check the actual numbers do NOT fire if the value is NaN or the text box isn't filled out.
  //so `factValue>10 && factValue<100` should not fire true if the number is a NaN.
  if (typeOfFactValue === 'number' && Number.isNaN(factValue)) {
    return false;
  }
  const parsedValue = parseArray(value);
  const modifiedFactValue =
    typeof factValue === 'string' && factValue.indexOf('e') === -1
      ? parseFloat(factValue)
      : factValue;
  if (!Array.isArray(parsedValue) || !isNumber(modifiedFactValue)) {
    return false;
  }
  let [min, max] = parsedValue; // 3rd param is tolerance if/when enabled
  // BS: apparently min/max can have expressions ["{stage.foo.value}", "8.3", 0.0] so they will need to be strings
  // and currently expressions will break until we add support for them
  min = parseFloat(min);
  max = parseFloat(max);

  const isInRange = modifiedFactValue >= min && modifiedFactValue <= max;

  return isInRange;
};

export const notInRangeOperator = (factValue: any, value: any): boolean => {
  const typeOfFactValue = typeof factValue;
  //the rules that check the actual numbers do NOT fire if the value is NaN or the text box isn't filled out.
  //so `factValue>10 && factValue<100` should not fire true if the number is a NaN.
  if (typeOfFactValue === 'number' && Number.isNaN(factValue)) {
    return false;
  }
  return !inRangeOperator(factValue, value);
};
const operators = {
  inRange: inRangeOperator,
  notInRange: notInRangeOperator,
};

export default operators;
