const round = (num: number, decimalPositions: number) => {
  const m = Math.pow(10, decimalPositions);
  return Math.round(num * m) / m;
};

const linSearch = (arr: string, key: string) => {
  const newArr = arr.split(',');
  for (let i = 0; i < arr.length; i = i + 1) {
    if (newArr[i] === key) return key;
  }
  return null;
};

const intDivide = (a: number, b: number) => {
  const division = Number(a) / Number(b);
  if (division < 0) {
    return Math.ceil(division);
  }

  return Math.floor(division);
};

const random = (lower: number, upper: number, decimalPositions = 0) => {
  if (lower === undefined) {
    return Math.random();
  }
  if (decimalPositions === 0) {
    // Return random integer value beween lower and upper, exluding upper,
    // but including lower
    return Math.floor(Math.random() * (upper - lower)) + lower;
  }

  const value = Math.random() * (upper - lower) + lower;
  const result = '' + value;
  const dot = result.lastIndexOf('.');

  if (dot === -1) {
    return Number(result);
  }

  return Number(result.substr(0, dot + (decimalPositions + 1)));
};

const randomInt = (min: number, max: number) => {
  const minVal = Math.ceil(min);
  const maxVal = Math.floor(max);
  return Math.floor(Math.random() * (maxVal - minVal)) + minVal;
};

const almostEqual = (a: number, b: number, difference = 10 ** -7) => {
  return Math.abs(a - b) < difference;
};

const sumArray = (arr: string[]) => {
  return arr.reduce((total, val) => total + Number(val), 0);
};

export const em = {
  almostEqual,

  fracA2: (n: number, d: number) => {
    return n + ',' + d;
  },
  frac2Tex: (n: number, d: number) => '\\frac{' + n + '}{' + d + '}',

  abs: (x: number) => Math.abs(x),

  ceil: (x: number) => Math.ceil(x),

  floor: (x: number) => Math.floor(x),

  factorial: (n: number) => {
    let result = 1;
    for (let i = n; i > 0; i = i - 1) {
      result = result * i;
    }
    return result;
  },

  gcd: (x: number, y: number) => {
    let absX = Math.abs(x);
    let absY = Math.abs(y);
    while (absY) {
      const t = absY;
      absY = absX % absY;
      absX = t;
    }
    return absX;
  },

  log: (n: number, base = Math.E) => Math.log(n) / Math.log(base),

  max: (a: number, b: number) => Math.max(a, b),

  min: (a: number, b: number) => Math.min(a, b),

  sqrt: (n: number) => Math.sqrt(n),

  sin: (x: number) => {
    return Math.sin(x);
  },

  cos: (x: number) => {
    return Math.cos(x);
  },

  tan: (x: number) => {
    return Math.tan(x);
  },

  PI: Math.PI,

  exp: (x: number) => {
    return Math.exp(x);
  },

  pow: (x: number, y: number) => {
    return Math.pow(x, y);
  },
  toRadians: (d: number) => {
    return d * (Math.PI / 180);
  },
  sizeStrs: (arr: string) => arr.split(',').length,
  mod: (a: number, b: number) => {
    return a % b;
  },
  getAV: (arr: string, index: number) => {
    if (arr.startsWith('"')) {
      return arr.substring(1, arr.length - 2).split(',')[index + 1];
    }
    return arr.split(',')[index - 1];
  },
  randomArray: (arr: any[]) => {
    return arr[randomInt(0, arr.length)];
  },
  randomBetween: (l: number, u: number) => {
    return Math.random() * (u - l) + l;
  },

  randomS: (lower: number, upper: number, except: string) => {
    let upperVal = upper;
    let lowerVal = lower;

    if (upperVal === undefined) {
      upperVal = lowerVal;
      lowerVal = 0;
    }
    let item = null;
    let count = 0;
    const exceptVal = '' + except;
    do {
      item = em.randomInt(lowerVal, upperVal + 1);
      count = count + 1;
    } while (linSearch(exceptVal, item + '') != null || count <= upperVal - lowerVal);
    if (linSearch(exceptVal, item + '') != null) return null;
    return item;
  },

  random,

  randomInt,

  round: (number: number, decimalPositions = 1) => {
    return round(number, decimalPositions);
  },
  roundA: (number: number, decimalPositions: number) => {
    return round(number, decimalPositions);
  },
  sortNum: (arr: string) => {
    let result;
    if (arr.startsWith('"')) {
      result = arr.substring(1, arr.length - 2).split(',');
    } else {
      result = arr.split(',');
    }
    return (
      '"' +
      result
        .map((n) => Number(n))
        .sort((a, b) => a - b)
        .join(',') +
      '"'
    );
  },

  mean: (arr: string) => {
    if (arr === '') throw 'Input must contain at least one element.';

    let items = [];
    if (arr.startsWith('"')) {
      items = arr.substring(1, arr.length - 2).split(',');
    } else {
      items = arr.split(',');
    }
    return sumArray(items) / items.length;
  },

  median: (arr: string) => {
    if (arr === '') throw 'Input must contain at least one element.';
    const sortedString = em.sortNum(arr).substring(1, arr.length + 1);
    let items = [];
    if (arr.startsWith('"')) {
      items = sortedString.substring(1, sortedString.length - 2).split(',');
    } else {
      items = sortedString.split(',');
    }
    if (items.length % 2 === 1) return Number(items[intDivide(items.length, 2)]);
    return (
      (Number(items[intDivide(items.length, 2) - 1]) + Number(items[intDivide(items.length, 2)])) /
      2
    );
  },

  mode: (arr: string) => {
    if (arr === '') throw 'Input must contain at least one element.';
    let items = [];
    if (arr.startsWith('"')) {
      items = arr.substring(1, arr.length - 2).split(',');
    } else {
      items = arr.split(',');
    }

    const counts = {} as any;
    for (const count in items) {
      if (items[count] in counts) {
        counts[items[count]] += 1;
      } else {
        counts[items[count]] = 1;
      }
    }

    // Check if everything is the same first (no mode):

    let allSame = true;
    for (const i in items) {
      if (counts[items[0]] !== counts[items[i]]) allSame = false;
    }
    if (allSame) return null;
    let maxCount = counts[items[0]];
    let maximum = items[0];
    for (const j in counts) {
      if (counts[j] > maxCount) {
        maxCount = counts[j];
        maximum = j;
      }
    }
    return Number(maximum);
  },

  variance: (arr: string) => {
    if (arr === '') throw 'Input must contain at least one element.';
    let items = [];
    if (arr.startsWith('"')) {
      items = arr.substring(1, arr.length - 2).split(',');
    } else {
      items = arr.split(',');
    }

    const arrMean = Number(em.mean(items.join(',')));
    items = items.map((n) => (arrMean - Number(n)) ** 2);
    return Number(em.mean(items.join(',')));
  },

  standardDeviation: (arr: string) => Math.sqrt(em.variance(arr)),
};
