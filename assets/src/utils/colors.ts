const hashString = (string: string) => {
  const seed = 131;
  const seed2 = 137;
  let hash = 0;

  // make hash more sensitive for short string like 'a', 'b', 'c'
  const str = string + 'x';

  // Number.MAX_SAFE_INTEGER equals 9007199254740991
  const MAX_SAFE_INTEGER = parseInt(`${Number.MAX_SAFE_INTEGER / seed2}`, 10);

  for (let i = 0; i < str.length; i = i + 1) {
    if (hash > MAX_SAFE_INTEGER) {
      hash = parseInt(`${hash / seed2}`, 10);
    }
    hash = hash * seed + str.charCodeAt(i);
  }
  return hash;
};

const rgbToHex = (RGBArray: any) => {
  let hex = '#';
  RGBArray.forEach((value: any) => {
    if (value < 16) {
      hex = hex + 0;
    }
    hex = hex + value.toString(16);
  });

  return hex;
};

const hslToRgb = (hue: number, sat: number, light: number) => {
  const H = hue / 360;
  const S = sat;
  const L = light;

  const q = L < 0.5 ? L * (1 + S) : L + S - L * S;
  const p = 2 * L - q;

  return [H + 1 / 3, H, H - 1 / 3].map((c) => {
    let color = c;

    if (color < 0) {
      color = color + 1;
    }
    if (color > 1) {
      color = color - 1;
    }
    if (color < 1 / 6) {
      color = p + (q - p) * 6 * color;
    } else if (color < 0.5) {
      color = q;
    } else if (color < 2 / 3) {
      color = p + (q - p) * 6 * (2 / 3 - color);
    } else {
      color = p;
    }
    return Math.round(color * 255);
  });
};

/**
 * Set of functions that return the color based on the hash of a string.
 */
export const stringToColor = {
  hsl: (str: string, minH = 0, maxH = 360) => {
    let hash = hashString(str);

    const H = hash % 359;
    const S = [0.35, 0.5, 0.65];
    const L = [0.35, 0.5, 0.65];

    const h = (H / 1000) * (maxH - minH) + minH;

    hash = parseInt(`${hash / 360}`, 10);
    const s = S[hash % S.length];

    hash = parseInt(`${hash / S.length}`, 10);
    const l = L[hash % L.length];

    return [h, s, l];
  },
  rgb: (str: string) => {
    const [h, s, l] = stringToColor.hsl(str);
    return hslToRgb(h, s, l);
  },
  hex: (str: string) => {
    const rgb = stringToColor.rgb(str);
    return rgbToHex(rgb);
  },
};
