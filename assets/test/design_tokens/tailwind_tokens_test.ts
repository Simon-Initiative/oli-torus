import tokens from '../../tailwind.tokens';

type Theme = 'light' | 'dark';
type TokenName = keyof typeof tokens;

const value = (name: TokenName, theme: Theme): string =>
  (tokens[name] as Record<Theme, string>)[theme];

const channel = (hex: string, start: number) => {
  const c = parseInt(hex.slice(start, start + 2), 16) / 255;
  return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
};

const luminance = (hex: string) =>
  0.2126 * channel(hex, 1) + 0.7152 * channel(hex, 3) + 0.0722 * channel(hex, 5);

const contrast = (a: string, b: string) => {
  const [lighter, darker] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (lighter + 0.05) / (darker + 0.05);
};

const pairs: [string, TokenName, TokenName][] = [
  ['primary button', 'Text-text-white', 'Fill-Buttons-fill-primary'],
  [
    'primary button on hover',
    'Specially-Tokens-Text-text-button-primary-hover',
    'Fill-Buttons-fill-primary-hover',
  ],
];

describe('primary button colour tokens', () => {
  describe.each(pairs)('%s', (_label, text, fill) => {
    it.each(['light', 'dark'] as Theme[])(
      `%s theme: ${text} on ${fill} reaches the 4.5:1 text contrast minimum`,
      (theme) => {
        const foreground = value(text, theme);
        const background = value(fill, theme);

        expect(foreground).toMatch(/^#[0-9A-Fa-f]{6}$/);
        expect(background).toMatch(/^#[0-9A-Fa-f]{6}$/);
        expect(contrast(foreground, background)).toBeGreaterThanOrEqual(4.5);
      },
    );
  });
});
