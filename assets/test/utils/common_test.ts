import {
  isNumber,
  isString,
  isStringArray,
  parseArray,
  parseBoolean,
  valueOr,
  zip,
  removeEmpty,
} from 'utils/common';

describe('common valueOr', () => {
  it('should use default value when null', () => {
    expect(valueOr(null, 'apple')).toBe('apple');
  });

  it('should use default value when undefined', () => {
    expect(valueOr(undefined, 'apple')).toBe('apple');
  });

  it('should use provided value', () => {
    expect(valueOr('orange', 'apple')).toBe('orange');
  });
});

describe('common isString', () => {
  it('should return true for a string', () => {
    expect(isString('shoes')).toEqual(true);
  });

  it('should return false for any other type', () => {
    expect(isString(9)).toEqual(false);
  });
});

describe('common isNumber', () => {
  it('should return true for a number', () => {
    expect(isNumber(9)).toEqual(true);
  });

  it('should return false for NaN', () => {
    expect(isNumber(parseFloat('shoes'))).toEqual(false);
  });

  it('should return false for any non number', () => {
    expect(isNumber('abc')).toEqual(false);
  });
});

describe('common parseBoolean', () => {
  it('should return true for boolean true', () => {
    expect(parseBoolean(true)).toEqual(true);
  });

  it('should return true for string true', () => {
    expect(parseBoolean('true')).toEqual(true);
  });

  it('should return true for number 1', () => {
    expect(parseBoolean(1)).toEqual(true);
  });

  it('should return true for string 1', () => {
    expect(parseBoolean('1')).toEqual(true);
  });

  it('should return false even for truthy strings', () => {
    expect(parseBoolean('false')).toEqual(false);
  });

  it('should return false even for truthy numbers', () => {
    expect(parseBoolean(9)).toEqual(false);
  });
});

describe('common isStringArray', () => {
  it('should return true for a string that looks like an array', () => {
    expect(isStringArray('[shoes]')).toEqual(true);
  });

  it('should return false for any other type', () => {
    expect(isStringArray(['shoes'])).toEqual(false);
  });
});

describe('common parseArray', () => {
  it('should return the array if it is actually an array', () => {
    const arr = [1, 2, 3];
    expect(parseArray(arr)).toEqual(arr);
  });

  it('should parse a string array of numbers into an array', () => {
    const expected = [1, 2, 3];
    expect(parseArray('[1,2,3]')).toEqual(expected);
  });

  it('should parse an array-like string into a valid array', () => {
    const str = '[some, thing, silly]';
    const expected = ['some', 'thing', 'silly'];
    expect(parseArray(str)).toEqual(expected);
  });

  it('should parse an array-like decimal string into a valid number array', () => {
    const str = '[.000025,.000015,.000006,.000008]';
    const expected = [0.000025, 0.000015, 0.000006, 0.000008];
    expect(parseArray(str)).toEqual(expected);
  });

  it('should parse an array-like string into a valid array', () => {
    const str = '["some", "thing", "silly","-56.5/-13/70"]';
    const expected = ['some', 'thing', 'silly', '-56.5/-13/70'];
    expect(parseArray(str)).toEqual(expected);
  });

  it('should support 2d arrays', () => {
    const str = '[[1,2],[3,4]]';
    const expected = [
      [1, 2],
      [3, 4],
    ];
    expect(parseArray(str)).toEqual(expected);
  });
});

describe('common removeEmpty', () => {
  it('removes items with no content', () => {
    const hasContent1 = {
      content: {
        model: [{ type: 'p', children: [{ text: 'hey' }] }],
      },
    };
    const hasContent2 = {
      content: [{ type: 'img', children: [{ text: '' }] }],
    };

    const noContent: any[] = [
      {
        content: {
          model: [{ type: 'p', children: [{ text: '' }] }],
        },
      },
      {
        content: {
          model: [{ type: 'p', children: [{ text: '' }, { text: ' ' }, { text: '\n' }] }],
        },
      },
      {
        content: {
          model: [{ text: '' }],
        },
      },
      {
        content: [{ text: '' }, { text: '   ' }, { text: '\n' }],
      },
      {
        content: [{ type: 'p', children: [{ type: 'p', children: [{ text: '   ' }] }] }],
      },
    ];

    const removed = removeEmpty([hasContent1, hasContent2, ...noContent]);

    expect(removed[0]).toBe(hasContent1);
    expect(removed[1]).toBe(hasContent2);
  });
});

describe('zip', () => {
  const xs1 = ['a', 'b', 'c'];
  const xs2 = ['d', 'e', 'f'];
  const xs3 = ['g', 'h', 'i', 'j'];
  const xs4: string[] = [];
  it('should zip', () => {
    expect(zip(xs1, xs2)).toEqual([
      ['a', 'd'],
      ['b', 'e'],
      ['c', 'f'],
    ]);
    expect(zip(xs1, xs3)).toEqual([
      ['a', 'g'],
      ['b', 'h'],
      ['c', 'i'],
    ]);
    expect(zip(xs1, xs4)).toEqual([]);
    expect(zip(xs4, xs1)).toEqual([]);
  });
});
