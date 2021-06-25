import { CSSProperties } from 'react';

// async because this may change to calling an authoring function of the part component
export const createSimpleText = async (msg: string, style: CSSProperties = {}) => {
  const textComponent = {
    custom: {
      nodes: [
        {
          tag: 'p',
          children: [
            {
              tag: 'span',
              style,
              children: [
                {
                  tag: 'text',
                  text: msg,
                  children: [],
                },
              ],
            },
          ],
        },
      ],
      x: 10.0,
      width: 330.0,
      y: 10.0,
      z: 0.0,
      palette: {
        fillColor: 1.6777215e7,
        fillAlpha: 0.0,
        lineColor: 1.6777215e7,
        lineAlpha: 0.0,
        lineThickness: 0.1,
        lineStyle: 0.0,
      },
      customCssClass: '',
      height: 22.0,
    },
  };
  return textComponent;
};
