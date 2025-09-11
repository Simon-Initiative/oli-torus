import { CSSProperties } from 'react';
import guid from 'utils/guid';

// async because this may change to calling an authoring function of the part component
export const createSimpleText = async (
  msg: string,
  style: CSSProperties = { fontSize: '1rem' },
  transform = { x: 10, y: 10, z: 0, width: 330, height: 22 },
) => {
  const textComponent = {
    id: `text_${guid()}`,
    type: 'janus-text-flow',
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
      x: transform.x || 0,
      y: transform.y || 0,
      z: transform.z || 0,
      width: transform.width || 100,
      height: transform.height || 50,
      palette: {
        fillColor: 1.6777215e7,
        fillAlpha: 0.0,
        lineColor: 1.6777215e7,
        lineAlpha: 0.0,
        lineThickness: 0.1,
        lineStyle: 0.0,
      },
      customCssClass: '',
    },
  };
  return textComponent;
};
