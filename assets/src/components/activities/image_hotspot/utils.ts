import { getShape, Hotspot, ImageHotspotModelSchema, makeHotspot } from './schema';
import { makeStem, makeHint, makePart } from '../types';

import { Responses } from 'data/activities/model/responses';

export const defaultImageHotspotModel: () => ImageHotspotModelSchema = () => {
  const hotspot1: Hotspot = makeHotspot();
  // initialize for default single selection. Will need different CATA-style
  // response structure if dynamically changed to multiple selection
  const responses = Responses.forMultipleChoice(hotspot1.id);
  return {
    stem: makeStem(''),
    imageURL: undefined,
    choices: [hotspot1],
    multiple: false,
    authoring: {
      parts: [makePart(responses, [makeHint(''), makeHint(''), makeHint('')], '1')],
      correct: [[], ''],
      transformations: [],
      targeted: [],
      previewText: '',
    },
  };
};

export const HS_COLOR = '#00a2ff';

export const drawHotspotShape = (
  ctx: CanvasRenderingContext2D,
  hs: Hotspot,
  color: string,
  border: boolean = true,
) => {
  ctx.lineWidth = 2;
  ctx.strokeStyle = '#000000';
  ctx.fillStyle = color;

  if (getShape(hs) === 'rect') {
    const [left, top, right, bot] = hs.coords;
    if (border) ctx.strokeRect(left, top, right - left, bot - top);
    ctx.fillRect(left, top, right - left, bot - top);
  } else if (getShape(hs) === 'circle') {
    const [cx, cy, r] = hs.coords;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
    ctx.closePath();
    if (border) ctx.stroke();
    ctx.fill();
  } else if (getShape(hs) === 'poly') {
    ctx.beginPath();
    ctx.moveTo(hs.coords[0], hs.coords[1]);
    for (var i = 2; i < hs.coords.length; i += 2) {
      ctx.lineTo(hs.coords[i], hs.coords[i + 1]);
    }
    ctx.closePath();
    if (border) ctx.stroke();
    ctx.fill();
  }
};
