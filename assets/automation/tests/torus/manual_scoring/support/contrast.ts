function parseRgba(value: string) {
  const channels = value
    .match(/^rgba?\(([^)]*)\)$/)?.[1]
    .split(/[\s,/]+/)
    .filter(Boolean);

  if (!channels || channels.length < 3) throw new Error(`Unsupported colour syntax: ${value}`);

  const [r, g, b, a = 1] = channels.map(Number);
  return [r, g, b, a];
}

/**
 * WCAG contrast ratio of two computed colours. A translucent foreground is blended over the
 * background; a translucent background depends on what lies behind it, so it fails instead of
 * being measured.
 */
export function contrast(foreground: string, background: string) {
  const [br, bg, bb, ba] = parseRgba(background);

  if (ba !== 1)
    throw new Error(`Cannot measure contrast over a translucent background: ${background}`);

  const [r, g, b, a] = parseRgba(foreground);
  const seen = [r, g, b].map((c, i) => c * a + [br, bg, bb][i] * (1 - a));
  const luminance = (rgb: number[]) => {
    const [lr, lg, lb] = rgb.map((c) => {
      const s = c / 255;
      return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * lr + 0.7152 * lg + 0.0722 * lb;
  };
  const [x, y] = [luminance(seen), luminance([br, bg, bb])].sort((m, n) => n - m);

  return (x + 0.05) / (y + 0.05);
}
