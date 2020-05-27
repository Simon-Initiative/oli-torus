import { measureTextWidth } from 'utils/measure';

export const convert = {

  // Converts a zero-based index to an alpha notation.
  //
  // Examples:
  //   0 -> 'A'
  //   1 -> 'B'
  //   25 -> 'Z'
  //   26 -> 'AA'
  //   27 -> 'AB'
  //
  toAlphaNotation: (index: number): string => {
    if (index === undefined || index === null || index < 0) {
      return '';
    }

    let num = index;
    let rem;

    let result = '';

    do {

      rem = num % 26;
      num = Math.floor(num / 26);

      // A pure conversion to base 26 that didn't use 0-9 would
      // have to treat A as the zero.  This leads to a problem where
      // we cannot yield our 'AA' as a desired representation for the
      // value 26, since that effectively is '00', instead this algorithm
      // would produce 'BA' aka '10' in regular base 26.  We can correct
      // this by simply adjusting the first, leftmost digit, when there are
      // more than one digits, by one (turning that leading B into an A).
      const adjustment = num === 0 && result.length !== 0 ? -1 : 0;
      result = String.fromCharCode((rem + adjustment + 65)) + result;

    } while (num !== 0);

    return result;

  },

  /**
   * Returns the string representation of bytes converted to the correct units.
   * Inspired by Bytes utility https://github.com/visionmedia/bytes.js
   * @param value value to convert to string
   * @param decimalPlaces number of decimal places to include in result
   */
  toByteNotation: (value: number, decimalPlaces: number = 2) => {
    if (!Number.isFinite(value)) {
      return null;
    }

    const UNIT_MAP = {
      b:  1,
      kb: 1 << 10,
      mb: 1 << 20,
      gb: 1 << 30,
      tb: ((1 << 30) * 1024),
    } as any;

    const mag = Math.abs(value);
    let unit;

    if (mag >= UNIT_MAP.tb) {
      unit = 'TB';
    } else if (mag >= UNIT_MAP.gb) {
      unit = 'GB';
    } else if (mag >= UNIT_MAP.mb) {
      unit = 'MB';
    } else if (mag >= UNIT_MAP.kb) {
      unit = 'KB';
    } else {
      unit = 'B';
    }

    const val = value / UNIT_MAP[unit.toLowerCase()];
    const str = val.toFixed(decimalPlaces).replace(/^(.+)\.?[0]+$/, '$1').replace(/\.0$/, '');

    return `${str} ${unit}`;
  },

  numberToWords: (num: number) => {
    const ones = ['', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'];
    const tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
      'eighty', 'ninety'];
    const teens = ['ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
      'seventeen', 'eighteen', 'nineteen'];

    const convertMillions = (num: number) : string => {
      if (num >= 1000000) {
        return convertMillions(Math.floor(num / 1000000))
          + ' million ' + convertThousands(num % 1000000);
      }
      return convertThousands(num);
    };

    const convertThousands = (num: number) => {
      if (num >= 1000) {
        return convertHundreds(Math.floor(num / 1000))
          + ' thousand ' + convertHundreds(num % 1000);
      }
      return convertHundreds(num);
    };

    const convertHundreds = (num: number) => {
      if (num > 99) {
        return ones[Math.floor(num / 100)] + ' hundred ' + convertTens(num % 100);
      }
      return convertTens(num);
    };

    const convertTens = (num: number) => {
      if (num < 10) return ones[num];
      if (num >= 10 && num < 20) return teens[num - 10];
      return tens[Math.floor(num / 10)] + ' ' + ones[num % 10];
    };

    if (num === 0) return 'zero';
    return convertMillions(num);
  },

  /**
   * Converts a decimal number to a percentage
   */
  toPercentage: (value: number) => Math.round(value * 100) + '%',
};

export const stringFormat = {
  /**
   * Returns a truncated version of a string with elipsis
   * @param text string to truncate
   * @param maxLength max length of the truncated string
   * @param postfixLength optional length of the end part of the truncated string to include
   */
  ellipsize: (text: string, maxLength: number, postfixLength: number = 0) => {
    if (maxLength <= postfixLength + 3) {
      throw Error('maxLength must be greater than postfixLength + 3');
    }
    if (text.length > maxLength) {
      const front = text.substr(0, Math.min(maxLength, text.length) - 3 - postfixLength);

      return `${front}...${text.substr(text.length - postfixLength, text.length)}`;
    }

    return text;
  },

  /**
   * Returns a truncated version of a string with ellipsis.
   * Maximum string length is 500 characters. Larger strings will be truncated
   * to prevent the JavaScript event loop from locking up.
   *
   * WARNING: This might be an expensive call, as it renders the text into a canvas
   * element to measure it
   */
  ellipsizePx: (
    text: string, maxWidth: number, fontFamily: string,
    fontSize: number, fontWeight?: number, fontStyle?: string) => {
    const MAX_TEXT_LENGTH = 500;
    const ellipsizeWidth = measureTextWidth({
      text: '...', fontFamily, fontSize, fontWeight, fontStyle });
    const textWidth = measureTextWidth({
      text, fontFamily, fontSize, fontWeight, fontStyle });

    if (textWidth <= maxWidth) {
      return text;
    }

    if (maxWidth <= ellipsizeWidth) {
      console.error('ellipsizePx: maxWidth must be greater than size of ellipsis \'...\'');
      return '...';
    }

    const findLargestString = (str: string) : string => {
      return measureTextWidth({
        text: `${str}...`, fontFamily, fontSize, fontWeight, fontStyle }) <= maxWidth
        ? str
        : findLargestString(str.substr(0, str.length - 1));
    };

    return findLargestString(text.substr(0, MAX_TEXT_LENGTH)) + '...';
  },

};
