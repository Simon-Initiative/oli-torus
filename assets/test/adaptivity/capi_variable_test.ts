import {
  CapiVariable,
  CapiVariableTypes,
  coerceCapiValue,
  getCapiType,
  isSpecialArrayString,
  parseCapiValue,
} from 'adaptivity/capi';

describe('getCapiType', () => {
  it('detects ENUM when allowedValues are all strings', () => {
    expect(getCapiType('a', ['a', 'b'])).toBe(CapiVariableTypes.ENUM);
  });

  it('detects BOOLEAN for booleans and "true"/"false" strings', () => {
    expect(getCapiType(true)).toBe(CapiVariableTypes.BOOLEAN);
    expect(getCapiType('true')).toBe(CapiVariableTypes.BOOLEAN);
    expect(getCapiType('false')).toBe(CapiVariableTypes.BOOLEAN);
  });

  it('detects NUMBER for numeric values', () => {
    expect(getCapiType(42)).toBe(CapiVariableTypes.NUMBER);
  });

  it('detects ARRAY for real arrays and ordinary array strings', () => {
    expect(getCapiType([1, 2, 3])).toBe(CapiVariableTypes.ARRAY);
    expect(getCapiType('["0.12"]')).toBe(CapiVariableTypes.ARRAY);
  });

  it('treats leading-zero decimal array strings as STRING (sim-sensitive)', () => {
    // ["00.12"] must stay STRING so the sim does not choke (see isSpecialArrayString)
    expect(getCapiType('["00.12"]')).toBe(CapiVariableTypes.STRING);
  });

  it('detects STRING for plain text and UNKNOWN for unhandled types', () => {
    expect(getCapiType('hello')).toBe(CapiVariableTypes.STRING);
    expect(getCapiType(undefined)).toBe(CapiVariableTypes.UNKNOWN);
  });
});

describe('isSpecialArrayString', () => {
  it('flags leading-zero decimals but not normal decimals', () => {
    expect(isSpecialArrayString('["00.12"]')).toBe(true);
    expect(isSpecialArrayString('["0.12"]')).toBe(false);
    expect(isSpecialArrayString('not an array')).toBe(false);
  });
});

describe('coerceCapiValue', () => {
  it('stringifies numbers via parseFloat', () => {
    expect(coerceCapiValue('42', CapiVariableTypes.NUMBER)).toBe('42');
    expect(coerceCapiValue(3.5, CapiVariableTypes.NUMBER)).toBe('3.5');
  });

  it('passes strings and math expressions through as strings', () => {
    expect(coerceCapiValue('hello', CapiVariableTypes.STRING)).toBe('hello');
    expect(coerceCapiValue('x^2', CapiVariableTypes.MATH_EXPR)).toBe('x^2');
  });

  it('normalizes booleans to "true"/"false" strings', () => {
    expect(coerceCapiValue(true, CapiVariableTypes.BOOLEAN)).toBe('true');
    expect(coerceCapiValue('false', CapiVariableTypes.BOOLEAN)).toBe('false');
  });

  it('validates ENUM membership and throws on invalid values', () => {
    expect(coerceCapiValue('a', CapiVariableTypes.ENUM, ['a', 'b'])).toBe('a');
    expect(() => coerceCapiValue('z', CapiVariableTypes.ENUM, ['a', 'b'])).toThrow();
  });

  it('returns an array for ARRAY values', () => {
    expect(Array.isArray(coerceCapiValue('[1,2]', CapiVariableTypes.ARRAY, null, true))).toBe(true);
  });
});

describe('parseCapiValue', () => {
  it('parses booleans back to real booleans', () => {
    const v = new CapiVariable({ key: 'flag', type: CapiVariableTypes.BOOLEAN, value: 'true' });
    expect(parseCapiValue(v)).toBe(true);
  });

  it('parses numbers back to real numbers', () => {
    const v = new CapiVariable({ key: 'n', type: CapiVariableTypes.NUMBER, value: '7' });
    expect(parseCapiValue(v)).toBe(7);
  });
});

describe('CapiVariable', () => {
  it('infers type from value when none is given and coerces the value', () => {
    expect(new CapiVariable({ key: 'n', value: 5 })).toMatchObject({
      type: CapiVariableTypes.NUMBER,
      value: '5',
    });
    expect(new CapiVariable({ key: 'b', value: 'true' })).toMatchObject({
      type: CapiVariableTypes.BOOLEAN,
      value: 'true',
    });
    expect(new CapiVariable({ key: 's', value: 'hello' })).toMatchObject({
      type: CapiVariableTypes.STRING,
      value: 'hello',
    });
  });

  it('honors an explicit type over inference', () => {
    const v = new CapiVariable({ key: 's', type: CapiVariableTypes.STRING, value: '42' });
    expect(v.type).toBe(CapiVariableTypes.STRING);
    expect(v.value).toBe('42');
  });

  it('defaults allowedValues to null and bindTo to null', () => {
    const v = new CapiVariable({ key: 'k', value: 1 });
    expect(v.allowedValues).toBeNull();
    expect(v.bindTo).toBeNull();
  });
});
