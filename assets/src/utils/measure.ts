const DEFAULT_CANVAS = document.createElement('canvas');
const DEFAULT_FONT_WEIGHT = 400;
const DEFAULT_FONT_STYLE = 'normal';

export const measureTextWidth = ({
  text,
  fontFamily,
  fontSize,
  fontWeight = DEFAULT_FONT_WEIGHT,
  fontStyle = DEFAULT_FONT_STYLE,
  canvas = DEFAULT_CANVAS,
}: any) => {
  const ctx: any = canvas.getContext('2d');
  ctx.font = `${fontWeight} ${fontStyle} ${fontSize} ${fontFamily}`;

  return ctx.measureText(text).width;
};
