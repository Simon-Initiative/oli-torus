import {
  ActivityModelSchema,
  Stem,
  Part,
  ChoiceIdsToResponseId,
  Transformation,
  Choice,
  RichText,
  makeChoice,
  makeContent,
} from '../types';
import { ID } from 'data/content/model/other';
import { CATACompatible } from '../check_all_that_apply/actions';

export class Hotspot implements Choice {
  id: ID;
  content: RichText;
  coords: number[];
  title?: string;
}

export type shapeType = 'circle' | 'rect' | 'poly';

export function getShape(hotspot: Hotspot): shapeType | undefined {
  const n = hotspot.coords.length;
  if (n === 3) return 'circle';
  if (n === 4) return 'rect';
  if (n >= 6 && n % 2 === 0) return 'poly';
  return undefined;
}

export function makeHotspot(coords: number[] = []): Hotspot {
  const hotspot = new Hotspot();
  const choice = makeChoice('');
  hotspot.id = choice.id;
  hotspot.content = choice.content;
  hotspot.coords = coords;
  return hotspot;
}

export interface ImageHotspotModelSchema extends ActivityModelSchema, CATACompatible {
  stem: Stem;
  imageURL: string | undefined;
  height?: number;
  width?: number;
  choices: Hotspot[];
  multiple: boolean;
  authoring: {
    // If multiple is true, we must provide a CATA model, in which response rules are complex and
    // correct holds an association list of correct choice ids to the matching response id
    correct: ChoiceIdsToResponseId;
    targeted: ChoiceIdsToResponseId[];
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}

export interface ModelEditorProps {
  model: ImageHotspotModelSchema;
  editMode: boolean;
}
