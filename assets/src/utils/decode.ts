// node.js compatability:
if (typeof btoa === 'undefined') {
  global.btoa = function (str: string) {
    return Buffer.from(str, 'binary').toString('base64');
  };
}
if (typeof atob === 'undefined') {
  global.atob = function (str: string) {
    return Buffer.from(str, 'base64').toString('binary');
  };
}

// From SO article:
// https://stackoverflow.com/questions/30106476/
// using-javascripts-atob-to-decode-base64-doesnt-properly-decode-utf-8-strings
export function b64DecodeUnicode(str: string) {
  // Going backwards: from bytestream, to percent-encoding, to original string.
  return decodeURIComponent(
    atob(str)
      .split('')
      .map((c) => {
        return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
      })
      .join(''),
  );
}

export function b64EncodeUnicode(str: string) {
  // first we use encodeURIComponent to get percent-encoded UTF-8,
  // then we convert the percent encodings into raw bytes which
  // can be fed into btoa.
  return btoa(
    encodeURIComponent(str).replace(/%([0-9A-F]{2})/g, function toSolidBytes(match, p1) {
      return String.fromCharCode(+('0x' + p1));
    }),
  );
}
