import { Maybe } from 'tsmonad';
// Helper. Assumes a correct ID is given
export function getByUnsafe(slice, predicate) {
    return Maybe.maybe(slice.find(predicate)).valueOrThrow(new Error('Could not find item in list ' + JSON.stringify(slice)));
}
export const getParts = (model) => model.authoring.parts;
export const getPartById = (model, id) => getByUnsafe(getParts(model), (p) => p.id === id);
export const STEM_PATH = '$.stem';
export const PREVIEW_TEXT_PATH = '$..previewText';
//# sourceMappingURL=utils.js.map