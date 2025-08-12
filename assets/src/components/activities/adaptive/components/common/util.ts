/* eslint-disable @typescript-eslint/no-non-null-assertion */
import chroma from 'chroma-js';
import { ColorPalette } from 'components/parts/types/parts';
import { parseNumString } from 'utils/common';

export const convertPalette = (palette: any) => {
  const paletteStyles: Partial<ColorPalette> = {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
    borderStyle: 'none',
    borderWidth: 0,
    borderRadius: 0,
  };

  if (palette) {
    if (palette.useHtmlProps) {
      paletteStyles.backgroundColor = palette.backgroundColor;
      paletteStyles.borderColor = palette.borderColor;
      paletteStyles.borderWidth = parseNumString(palette.borderWidth.toString());
      paletteStyles.borderStyle = palette.borderStyle;
      paletteStyles.borderRadius = parseNumString(palette.borderRadius.toString());
    } else {
      paletteStyles.borderWidth = `${palette.lineThickness ? palette.lineThickness + 'px' : 0}`;
      paletteStyles.borderRadius = 0;
      paletteStyles.borderStyle = palette.lineStyle === 0 ? 'none' : 'solid';
      let borderColor = 'transparent';
      if (palette.lineColor! >= 0) {
        borderColor = chroma(palette.lineColor || 0)
          .alpha(palette.lineAlpha || 0)
          .css();
      }
      paletteStyles.borderColor = borderColor;

      let bgColor = 'transparent';
      if (palette.fillColor! >= 0) {
        bgColor = chroma(palette.fillColor || 0)
          .alpha(palette.fillAlpha || 0)
          .css();
      }
      paletteStyles.backgroundColor = bgColor;
    }

    // now it is converted
    paletteStyles.useHtmlProps = true;
  }

  return paletteStyles;
};

/**
 * Parses a CSS-like padding shorthand string (1–4 space-separated values)
 * into a full 4-value padding string (top right bottom left).
 *
 * Rules:
 * 1 value  → applies to all four sides.
 * 2 values → first applies to top/bottom, second to left/right.
 * 3 values → first applies to top, second to left/right, third to bottom.
 *            (CSS doesn't officially support this for padding, but we handle it for flexibility.)
 * 4 values → applies to top, right, bottom, left respectively.
 *
 * @param input - Padding shorthand string entered by user.
 * @returns Full padding string in "top right bottom left" format.
 */
export const parsePaddingShorthand = (input: string): string => {
  if (!input) return '';

  const values = input.trim().split(/\s+/); // Split by any whitespace

  switch (values.length) {
    case 1:
      // One value → all sides equal
      return `${values[0]} ${values[0]} ${values[0]} ${values[0]}`;
    case 2:
      // Two values → top/bottom, left/right
      return `${values[0]} ${values[1]} ${values[0]} ${values[1]}`;
    case 3:
      // Three values → top, left/right, bottom (non-standard for padding)
      return `${values[0]} ${values[1]} ${values[2]} ${values[1]}`;
    case 4:
      // Four values → top, right, bottom, left
      return `${values[0]} ${values[1]} ${values[2]} ${values[3]}`;
    default:
      // More than 4 values is invalid → return empty string
      return '';
  }
};
