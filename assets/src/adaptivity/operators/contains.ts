import { isString, looksLikeAnArray, parseArray } from 'utils/common';

export const containsOperator = (inputValue: any, conditionValue: any) => {
  if (!conditionValue || !inputValue) {
    return false;
  }

  /* console.log('containsOperator', { inputValue, conditionValue }); */

  if (looksLikeAnArray(conditionValue)) {
    const conditionArray = parseArray(conditionValue);
    if (looksLikeAnArray(inputValue)) {
      const inputArray = parseArray(inputValue);
      // if the input is an array, the condition array should contain every one of the input array values
      return inputArray.every((item) => conditionArray.includes(item));
    } else {
      return conditionArray.includes(inputValue);
    }
  }

  if (isString(conditionValue)) {
    if (isString(inputValue)) {
      return inputValue.toLocaleLowerCase().includes(conditionValue.toLocaleLowerCase());
    }
    if (looksLikeAnArray(inputValue)) {
      const inputArray = parseArray(inputValue);
      return inputArray.includes(conditionValue);
    }
  }

  return false;
};

export const notContainsOperator = (inputValue: any, conditionValue: any) =>
  !containsOperator(inputValue, conditionValue);

export const containsAnyOfOperator = (inputValue: any, conditionValue: any) => {
  if (!conditionValue || !inputValue) {
    return false;
  }

  // the condition should always be an array, if it's a single value, it should be wrapped in an array
  const conditionArray = parseArray(conditionValue);
  if (looksLikeAnArray(inputValue)) {
    const inputArray = parseArray(inputValue);
    // if the input is an array, the condition array should contain at least one of the input array values
    return inputArray.some((item) => conditionArray.includes(item));
  } else {
    return conditionArray.includes(inputValue);
  }
};

export const notContainsAnyOfOperator = (inputValue: any, conditionValue: any) =>
  !containsAnyOfOperator(inputValue, conditionValue);

export const containsOnlyOperator = (inputValue: any, conditionValue: any) => {
  // inputValue contains ONLY items in conditionValue
  if (!conditionValue || !inputValue || (Array.isArray(inputValue) && inputValue.length < 1)) {
    return false;
  }

  // We are parseNumString for the cases where inputValue contains numbers but the values contain strings or vice-versa
  const updatedFacts = parseArray(inputValue);
  const updatedValues = parseArray(conditionValue);

  if (updatedValues.length !== updatedFacts.length) {
    return false;
  }

  return updatedFacts.every((fact: any) => updatedValues.includes(fact));
};

// case sensitive version of containsOperator
export const containsExactlyOperator = (inputValue: any, conditionValue: any) => {
  // inputValue is exactly equal to conditionValue
  if (!conditionValue || !inputValue) {
    return false;
  }

  /* console.log('containsExactlyOperator', { inputValue, conditionValue }); */

  if (looksLikeAnArray(conditionValue)) {
    const conditionArray = parseArray(conditionValue);
    if (looksLikeAnArray(inputValue)) {
      const inputArray = parseArray(inputValue);
      // if the input is an array, the condition array should contain every one of the input array values
      return inputArray.every((item) => conditionArray.includes(item));
    } else {
      return conditionArray.includes(inputValue);
    }
  }

  if (isString(conditionValue)) {
    if (isString(inputValue)) {
      return inputValue.includes(conditionValue);
    }
    if (looksLikeAnArray(inputValue)) {
      const inputArray = parseArray(inputValue);
      return inputArray.includes(conditionValue);
    }
  }

  return false;
};

export const notContainsExactlyOperator = (inputValue: any, conditionValue: any) =>
  !containsExactlyOperator(inputValue, conditionValue);

const operators = {
  contains: containsOperator,
  notContains: notContainsOperator,
  containsAnyOf: containsAnyOfOperator,
  notContainsAnyOf: notContainsAnyOfOperator,
  containsExactly: containsExactlyOperator,
  notContainsExactly: notContainsExactlyOperator,
  containsOnly: containsOnlyOperator,
};

export default operators;
