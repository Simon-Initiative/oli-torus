import { isString, parseArray } from 'utils/common';

const handleContainsOperator = (
  inputValue: any,
  conditionValue: any,
  isDoesNotContainsOperator: boolean,
  isContainsAnyOperator = false,
) => {
  if (!conditionValue || !inputValue) {
    return false;
  }

  console.log('handleContainsOperator', {
    inputValue,
    conditionValue,
    isDoesNotContainsOperator,
    isContainsAnyOperator,
  });

  if (isString(inputValue)) {
    if (!isString(conditionValue)) {
      // use case: inputValue = 'abc' and conditionValue = ['abc',' abc']
      if (Array.isArray(conditionValue)) {
        return conditionValue.some((item: any) => {
          let test = item;
          if (isString(item)) {
            test = test.trim().length ? test.trim() : test;
          }
          return inputValue.trim().length
            ? inputValue.trim().includes(test)
            : inputValue.includes(test);
        });
      }
      return false;
    }

    // use case: inputValue = 'abc' and conditionValue = 'abc' or conditionValue = 'abc,def'
    if (!conditionValue.includes(`[`) && !conditionValue.includes(']')) {
      const doesContain = conditionValue
        .toLocaleLowerCase()
        .includes(inputValue.toLocaleLowerCase());
      return doesContain;
    }

    // use case: inputValue = 'abc' and conditionValue = '[abc,def]'
    conditionValue = parseArray(conditionValue);
    return conditionValue.some((item: any) => {
      let test = item;
      if (isString(item)) {
        test = test.trim().length ? test.trim() : test;
      }
      return inputValue.trim().length
        ? inputValue.trim().includes(test)
        : inputValue.includes(test);
    });
  }

  if (Array.isArray(inputValue) && Array.isArray(conditionValue)) {
    const updatedFacts = parseArray(inputValue);
    const modifiedValue = parseArray(conditionValue);
    if (isDoesNotContainsOperator) {
      return (
        modifiedValue
          // check if conditionValue is found in inputValue array
          .every((item) => updatedFacts.includes(item))
      );
    } else {
      let hitCount = 0; // counts the number of values found

      modifiedValue.forEach((item) => {
        if (updatedFacts.includes(item)) {
          hitCount++;
        }
      });
      if (isContainsAnyOperator && hitCount > 0) {
        return true;
      } else if (hitCount === modifiedValue.length) {
        return true;
      } else {
        return false;
      }
    }
  } else if (Array.isArray(inputValue) && conditionValue) {
    // We are parseArrayString for the cases where inputValue contains strings but the values contain strings
    const updatedFacts = parseArray(inputValue);
    const updatedValue = parseArray(conditionValue);
    return updatedValue.some((item: any) => updatedFacts.includes(item));
  }

  return false;
};

export const containsOperator = (inputValue: any, conditionValue: any) => {
  return handleContainsOperator(inputValue, conditionValue, false);
};

export const notContainsOperator = (inputValue: any, conditionValue: any) =>
  !handleContainsOperator(inputValue, conditionValue, true);

export const containsAnyOfOperator = (inputValue: any, conditionValue: any) =>
  // inputValue contains any items in conditionValue
  handleContainsOperator(inputValue, conditionValue, false, true);

export const notContainsAnyOfOperator = (inputValue: any, conditionValue: any) =>
  // inputValue does not contain items in conditionValue
  !handleContainsOperator(inputValue, conditionValue, false, true);

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

export const containsExactlyOperator = (inputValue: any, conditionValue: any) => {
  // inputValue is exactly equal to conditionValue
  if (!conditionValue || !inputValue) {
    return false;
  }

  // We are parseNumString for the cases where inputValue contains numbers but the values contain strings or vice-versa
  const updatedFacts = parseArray(inputValue);
  const updatedValues = parseArray(conditionValue);

  if (Array.isArray(inputValue) && Array.isArray(conditionValue)) {
    return (
      updatedFacts.every((fact) => updatedValues.includes(fact)) &&
      updatedFacts.length == updatedValues.length
    );
  } else {
    return inputValue === conditionValue;
  }
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
