import { parseBoolean } from 'utils/common';
import { parseArrayString } from './contains';

export const isAnyOfOperator = (factValue: any, value: any): boolean => {
  if (!Array.isArray(value)) {
    return false;
  }
  return value.some((val) => isEqual(factValue, val));
};

export const isEqual = (factValue: any, value: any): boolean => {
  // There no point in moving forward if one of them are undefined
  if (value === undefined || factValue === undefined) {
    return false;
  }

  if (Array.isArray(factValue)) {
    let compareValue = value;
    const updatedFactValue = parseArrayString(factValue);
    if (Array.isArray(value)) {
      // ** We are doing this for the cases where factValue comes [2 , 5] but the values comes as ['2','5'] */
      // ** DT - making sure that value is of array type else value.map() will throw error. */
      compareValue = parseArrayString(factValue).sort();
    }

    // ** DT - Sorting both arrays. depending upon user selection in UI the array sometimes comes
    // ** like factValue=[2,5] and value = [5,2] which is right selection but it evaluates to false*/
    factValue.sort();
    return JSON.stringify(updatedFactValue) === JSON.stringify(compareValue);
  }

  const typeOfValue = typeof value;
  const typeOfFactValue = typeof factValue;
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
  return factValue === value;
};

export const notIsAnyOfOperator = (factValue: any, value: any) =>
  !isAnyOfOperator(factValue, value);

export const isNaNOperator = (factValue: any, value: any) =>
  value === (Number.parseFloat(factValue).toString() === 'NaN');

export const equalWithToleranceOperator = (factValue: any, value: any) => {
  const modifiedFactValue = typeof factValue === 'string' ? parseFloat(factValue) : factValue;
  if (!Array.isArray(value) || Number.isNaN(modifiedFactValue)) {
    return false;
  }
  const [baseValue, tolerance] = value;
  const valuesWithTolerance = getValueWithTolerance(baseValue, baseValue, tolerance);
  const isInRange =
    modifiedFactValue >= valuesWithTolerance.minToleranceValue &&
    modifiedFactValue <= valuesWithTolerance.maxToleranceValue;

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
    const minToleranceValue = baseMinValue - calculateMinWithToleranceValue;
    const maxToleranceValue = baseMaxValue + calculateMaxWithToleranceValue;
    newValue = {
      minToleranceValue: minToleranceValue,
      maxToleranceValue: maxToleranceValue,
    };
  }
  return newValue;
};
export const notEqualWithToleranceOperator = (factValue: any, value: any) =>
  !equalWithToleranceOperator(factValue, value);

export const notEqual = (factValue: any, value: any) => !isEqual(factValue, value);

const operators = {
  isAnyOf: isAnyOfOperator,
  notIsAnyOf: notIsAnyOfOperator,
  isNaN: isNaNOperator,
  equal: isEqual,
  is: isEqual,
  notIs: notEqual,
  equalWithTolerance: equalWithToleranceOperator,
  notEqualWithTolerance: notEqualWithToleranceOperator,
};

export default operators;
