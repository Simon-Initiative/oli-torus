import React from 'react';
import { makeTransformation, Transform } from '../types';
// Activities with one part have a hard-coded ID. This makes some lookup logic simpler.
export const DEFAULT_PART_ID = '1';
export const isShuffled = (transformations) => !!transformations.find((xform) => xform.operation === Transform.shuffle);
export const toggleAnswerChoiceShuffling = () => {
    return (model) => {
        const transformations = model.authoring.transformations;
        isShuffled(transformations)
            ? (model.authoring.transformations = transformations.filter((xform) => xform.operation !== Transform.shuffle))
            : model.authoring.transformations.push(makeTransformation('choices', Transform.shuffle));
    };
};
export const ShuffleChoicesOption = ({ onShuffle, model, }) => (<div className="form-check mb-2">
    <input onChange={onShuffle} className="form-check-input" type="checkbox" value="" checked={isShuffled(model.authoring.transformations)} id="shuffle-choices"/>
    <label className="form-check-label" htmlFor="shuffle-choices">
      Shuffle answer choices
    </label>
  </div>);
export function addOrRemove(item, list) {
    if (list.find((x) => x === item)) {
        return remove(item, list);
    }
    return list.push(item);
}
export function remove(item, list) {
    const index = list.findIndex((x) => x === item);
    if (index > -1) {
        list.splice(index, 1);
    }
}
export function setDifference(subtractedFrom, toSubtract) {
    return subtractedFrom.filter((x) => !toSubtract.includes(x));
}
export function setUnion(list1, list2) {
    return [...list2.reduce((acc, curr) => acc.add(curr), new Set(list1))];
}
//# sourceMappingURL=utils.jsx.map