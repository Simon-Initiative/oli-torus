import { isNumber } from 'utils/common';

export const inRangeOperator = (factValue: any, value: any): boolean => {
  const modifiedFactValue =
    typeof factValue === 'string' && factValue.indexOf('e') === -1
      ? parseFloat(factValue)
      : factValue;
  if (!Array.isArray(value) || !isNumber(modifiedFactValue)) {
    return false;
  }
  let [min, max] = value; // 3rd param is tolerance if/when enabled
  // BS: apparently min/max can have expressions ["{stage.foo.value}", "8.3", 0.0] so they will need to be strings
  // and currently expressions will break until we add support for them
  min = parseFloat(min);
  max = parseFloat(max);

  const isInRange = modifiedFactValue >= min && modifiedFactValue <= max;

  return isInRange;
};

export const notInRangeOperator = (factValue: any, value: any): boolean =>
  !inRangeOperator(factValue, value);

const operators = {
  inRange: inRangeOperator,
  notInRange: notInRangeOperator,
};

export default operators;
