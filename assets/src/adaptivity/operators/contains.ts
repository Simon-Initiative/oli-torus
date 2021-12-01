import { isString, parseArray, parseNumString } from 'utils/common';

const handleContainsOperator = (
  factValue: any,
  value: any,
  isDoesNotContainsOperator: boolean,
  isContainsAnyOperator = false,
) => {
  // factValue contains value, can contain other items
  if (!value || !factValue) {
    return false;
  }

  if (isString(factValue)) {
    if (!isString(value)) {
      // use case: factValue = 'abc' and value = ['abc',' abc']
      if (Array.isArray(value)) {
        return value.some((item: any) => {
          return factValue.trim().includes(item.trim());
        });
      }
      return false;
    }
    // TODO there are inconsistencies between the what the sim puts out Wan-C wan-C
    // Need to determine if we should force the sim to update or not to be consistent or be loose like this
    if (!value.includes(`[`) && !value.includes(']')) {
      return factValue.toLocaleLowerCase().includes(value.toLocaleLowerCase());
    }
    value = parseArray(value);
    return value.some((item: any) => factValue.includes(item.trim()));
  }

  if (Array.isArray(factValue) && Array.isArray(value)) {
    // We are parseNumString for the cases where factValue contains numbers but the values contain strings or vice-versa
    const updatedFacts = parseArray(factValue);
    const modifiedValue = parseArray(value);
    if (isDoesNotContainsOperator) {
      return (
        modifiedValue
          // check if value is found in factValue array
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
  } else if (Array.isArray(factValue) && value) {
    // We are parseArrayString for the cases where factValue contains strings but the values contain strings
    const updatedFacts = parseArray(factValue);
    const updatedValue = parseArray(value);
    return updatedValue.some((item: any) => updatedFacts.includes(item));
  }

  return false;
};

export const containsOperator = (factValue: any, value: any) => {
  return handleContainsOperator(factValue, value, false);
};

export const notContainsOperator = (factValue: any, value: any) =>
  !handleContainsOperator(factValue, value, true);

export const containsAnyOfOperator = (factValue: any, value: any) =>
  // factValue contains any items in value
  handleContainsOperator(factValue, value, false, true);

export const notContainsAnyOfOperator = (factValue: any, value: any) =>
  // factValue does not contain items in value
  !handleContainsOperator(factValue, value, false, true);

export const containsOnlyOperator = (factValue: any, value: any) => {
  // factValue contains ONLY items in value
  if (!value || !factValue || (Array.isArray(factValue) && factValue.length < 1)) {
    return false;
  }

  // We are parseNumString for the cases where factValue contains numbers but the values contain strings or vice-versa
  const updatedFacts = parseArray(factValue);
  const updatedValues = parseArray(value);

  if (updatedValues.length !== updatedFacts.length) {
    return false;
  }

  return updatedFacts.every((fact: any) => updatedValues.includes(fact));
};

export const containsExactlyOperator = (factValue: any, value: any) => {
  // factValue is exactly equal to value
  if (!value || !factValue) {
    return false;
  }

  // We are parseNumString for the cases where factValue contains numbers but the values contain strings or vice-versa
  const updatedFacts = parseArray(factValue);
  const updatedValues = parseArray(value);

  if (Array.isArray(factValue) && Array.isArray(value)) {
    return (
      updatedFacts.every((fact) => updatedValues.includes(fact)) &&
      updatedFacts.length == updatedValues.length
    );
  } else {
    return factValue === value;
  }
};

export const notContainsExactlyOperator = (factValue: any, value: any) =>
  !containsExactlyOperator(factValue, value);

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
