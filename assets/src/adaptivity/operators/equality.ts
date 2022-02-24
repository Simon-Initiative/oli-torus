import { parseBoolean, parseArray } from 'utils/common';

export const isAnyOfOperator = (factValue: any, value: any): boolean => {
  const parsedValue = parseArray(value);
  if (!Array.isArray(parsedValue)) {
    return false;
  }
  return parsedValue.some((val) => isEqual(factValue, val));
};

export const isEqual = (factValue: any, value: any): boolean => {
  // There no point in moving forward if one of them are undefined
  if (value === undefined || factValue === undefined) {
    return false;
  }

  const typeOfValue = typeof value;
  const typeOfFactValue = typeof factValue;
  //the rules that check the actual numbers do NOT fire if the value is NaN or the text box isn't filled out.
  //so `is not 32.06` should not fire true if the number is a NaN.
  if (typeOfValue === 'number' && Number.isNaN(factValue)) {
    return false;
  }
  if (Array.isArray(factValue)) {
    let compareValue = value;
    const updatedFactValue: any = parseArray(factValue);
    let updatedValue = value;
    //Need to parse before we check "if" condition else it will fail for cases where value = '[0,0]'.
    if (!Array.isArray(value) && typeOfValue === 'number') {
      updatedValue = `[${value}]`;
    }
    updatedValue = parseArray(updatedValue);
    if (Array.isArray(updatedValue)) {
      // ** We are doing this for the cases where factValue comes [2 , 5] but the values comes as ['2','5'] */
      // ** DT - making sure that value is of array type else value.map() will throw error. */
      compareValue = updatedValue.sort();
    }

    // ** DT - Sorting both arrays. depending upon user selection in UI the array sometimes comes
    // ** like factValue=[2,5] and value = [5,2] which is right selection but it evaluates to false*/
    updatedFactValue.sort();
    //compareValue = [] & updatedFactValue = ['']
    if (compareValue.toString() === updatedFactValue.toString()) {
      return true;
    }
    return JSON.stringify(updatedFactValue) === JSON.stringify(compareValue);
  }
  // for boolean values,  factValue comes as true and value comes as 'true'
  // and some factValue comes as 'true' and value comes as true
  if (typeOfFactValue === 'boolean') {
    return value.toString().toLowerCase() === 'true' ? true === factValue : false === factValue;
  }
  if (typeOfValue === 'boolean') {
    return factValue.toString().toLowerCase() === 'true' ? true === value : false === value;
  }
  if (typeOfValue === 'string' && (value === 'true' || value === 'false')) {
    return parseBoolean(value) === parseBoolean(factValue);
  }
  // For number type equality, factValue comes as '1' and value comes as 1 or vice versa
  if (typeOfValue === 'number') {
    return parseFloat(factValue) === value;
  } else if (typeOfFactValue === 'number') {
    return parseFloat(value) === factValue;
  }
  if (typeOfValue === 'string' && typeOfFactValue === 'string') {
    return value.trim().toLowerCase() === factValue.trim().toLowerCase();
  }
  return factValue === value;
};

export const notIsAnyOfOperator = (factValue: any, value: any) =>
  !isAnyOfOperator(factValue, value);

export const isNaNOperator = (factValue: any, value: any) =>
  parseBoolean(value) === (Number.parseFloat(factValue).toString() === 'NaN');

export const equalWithToleranceOperator = (
  factValue: any,
  value: any,
  calledFromNotEqualToToleranceOperator = false,
) => {
  const modifiedFactValue = typeof factValue === 'string' ? parseFloat(factValue) : factValue;
  /* console.log('EQT1', { factValue, value, modifiedFactValue }); */
  let arrValue: any[];
  try {
    arrValue = parseArray(value);
  } catch (e) {
    return false;
  }
  if (Number.isNaN(modifiedFactValue)) {
    return calledFromNotEqualToToleranceOperator;
  }
  const [baseValue, tolerance] = arrValue;

  //the rules that check the actual numbers do NOT fire if the value is NaN or the text box isn't filled out.
  //so `equalWithToleranceOperator/notEqualWithToleranceOperator 32.06` should not fire true if the number is a NaN.
  if (typeof baseValue === 'number' && Number.isNaN(factValue)) {
    return calledFromNotEqualToToleranceOperator;
  }
  const valuesWithTolerance = getValueWithTolerance(baseValue, baseValue, tolerance);
  const isInRange =
    modifiedFactValue >= valuesWithTolerance.minToleranceValue &&
    modifiedFactValue <= valuesWithTolerance.maxToleranceValue;
  /* console.log('EQT2', {
    factValue,
    arrValue,
    modifiedFactValue,
    isInRange,
    valuesWithTolerance,
    baseValue,
    tolerance,
  }); */
  return isInRange;
};

export const getValueWithTolerance = (
  baseMinValue: number,
  baseMaxValue: number,
  tolerance: number,
) => {
  let newValue = {
    minToleranceValue: baseMinValue,
    maxToleranceValue: baseMaxValue,
  };
  //If tolerance is not specified then do nothing and return the original values.
  if (tolerance > 0) {
    const calculateMinWithToleranceValue = (tolerance * baseMinValue) / 100;
    const calculateMaxWithToleranceValue = (tolerance * baseMaxValue) / 100;
    const minToleranceValue =
      baseMinValue >= 0
        ? baseMinValue - calculateMinWithToleranceValue
        : baseMinValue + calculateMinWithToleranceValue;
    const maxToleranceValue =
      baseMinValue >= 0
        ? baseMaxValue + calculateMaxWithToleranceValue
        : baseMinValue - calculateMinWithToleranceValue;
    newValue = {
      minToleranceValue: minToleranceValue,
      maxToleranceValue: maxToleranceValue,
    };
  }
  return newValue;
};
export const notEqualWithToleranceOperator = (factValue: any, value: any) => {
  return !equalWithToleranceOperator(factValue, value, true);
};

export const notEqual = (factValue: any, value: any) => {
  const typeOfValue = typeof value;
  //the rules that check the actual numbers do NOT fire if the value is NaN or the text box isn't filled out.
  //so `is not 32.06` should not fire true if the number is a NaN.
  if (typeOfValue === 'number' && Number.isNaN(factValue)) {
    return false;
  }
  return !isEqual(factValue, value);
};

const operators = {
  isAnyOf: isAnyOfOperator,
  notIsAnyOf: notIsAnyOfOperator,
  isNaN: isNaNOperator,
  equal: isEqual,
  is: isEqual,
  notIs: notEqual,
  notEqual: notEqual,
  equalWithTolerance: equalWithToleranceOperator,
  notEqualWithTolerance: notEqualWithToleranceOperator,
};

export default operators;
