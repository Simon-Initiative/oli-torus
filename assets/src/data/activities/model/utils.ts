import { Maybe } from 'tsmonad';
import { HasParts, Part } from 'components/activities/types';

// Helper. Assumes a correct ID is given
export function getByUnsafe<T>(slice: T[], predicate: (x: T, i: number) => boolean): T {
  return Maybe.maybe(slice.find(predicate)).valueOrThrow(
    new Error('Could not find item in list ' + JSON.stringify(slice)),
  );
}

export const getParts = (model: HasParts) => model.authoring.parts;

export const getPartById = (model: HasParts, id: string) =>
  getByUnsafe<Part>(getParts(model), (p) => p.id === id);

export const STEM_PATH = '$.stem';

export const PREVIEW_TEXT_PATH = '$..previewText';
