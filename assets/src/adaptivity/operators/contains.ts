import { isString, parseArray, parseNumString } from 'utils/common';

const handleContainsOperator = (factValue: any, value: any, isDoesNotContainsOperator: boolean) => {
  // factValue contains value, can contain other items
  if (!value || !factValue) {
    return false;
  }

  if (isString(factValue)) {
    if (!isString(value)) {
      return false;
    }
    // TODO there are inconsistencies between the what the sim puts out Wan-C wan-C
    // Need to determine if we should force the sim to update or not to be consistent or be loose like this
    if (!value.includes(`[`) && !value.includes(']')) {
      return factValue.toLocaleLowerCase().includes(value.toLocaleLowerCase());
    }
    value = parseArray(value);
    return (
      value
        // We are parseNumString for the cases where factValue contains numbers but the values contain strings
        .map((item: string) => parseNumString(item))
        // check if value is found in factValue array
        .some((item: any) => factValue.includes(item))
    );
  }

  if (Array.isArray(factValue) && Array.isArray(value)) {
    // We are parseNumString for the cases where factValue contains numbers but the values contain strings or vice-versa
    const updatedFacts = parseArray(factValue);
    const modifideValue = parseArray(value);
    if (isDoesNotContainsOperator) {
      return (
        modifideValue
          // check if value is found in factValue array
          .every((item) => updatedFacts.includes(item))
      );
    } else {
      return (
        modifideValue
          // check if value is found in factValue array
          .some((item) => updatedFacts.includes(item))
      );
    }
  } else if (Array.isArray(factValue) && value) {
    // We are parseArrayString for the cases where factValue contains strings but the values contain strings
    const updatedFacts = parseArray(factValue);
    // split value into array
    return (
      value
        .split(',')
        // We are parseNumString for the cases where factValue contains numbers but the values contain strings
        .map((item: string) => parseNumString(item))
        // check if value is found in factValue array
        .some((item: any) => updatedFacts.includes(item))
    );
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
  containsOperator(factValue, value);

export const notContainsAnyOfOperator = (factValue: any, value: any) =>
  // factValue does not contain items in value
  !containsAnyOfOperator(factValue, value);

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
