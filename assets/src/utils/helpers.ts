// parse value and return accurate boolean
// returns boolean values for both numbers and strings
export const parseBool = (val: any) => {
  // cast value to number
  const num: number = +val;
  // have to ignore the false searchValue in 'replace'
  return !isNaN(num) ? !!num : !!String(val).toLowerCase().replace('false', '');
};

const helpers = {
  parseBool,
};

export default helpers;
