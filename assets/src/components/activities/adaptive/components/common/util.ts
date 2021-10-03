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
