const regex = /^-?\d+(\.\d+)?([eE][-+]?\d+)?$/;
export const isValidNumber = (value: string) => regex.test(value);
