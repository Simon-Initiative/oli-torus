import React from 'react';
import {
  HasPerPartSubmissionOption,
  makeTransformation,
  PartId,
  Transform,
  Transformation,
} from '../types';

export const isShuffled = (transformations: Transformation[]): boolean =>
  !!transformations.find((xform) => xform.operation === Transform.shuffle);

export const toggleAnswerChoiceShuffling = () => {
  return (model: { authoring: { transformations: Transformation[] } }): void => {
    const transformations = model.authoring.transformations;

    isShuffled(transformations)
      ? (model.authoring.transformations = transformations.filter(
          (xform) => xform.operation !== Transform.shuffle,
        ))
      : model.authoring.transformations.push(makeTransformation('choices', Transform.shuffle));
  };
};

export const togglePerPartSubmissionOption = () => {
  return (model: HasPerPartSubmissionOption): void => {
    model.submitPerPart =
      model.submitPerPart === undefined || model.submitPerPart === false ? true : false;
  };
};

interface ShuffleChoicesOptionProps {
  onShuffle: () => void;
  model: { authoring: { transformations: Transformation[] } };
}
export const ShuffleChoicesOption: React.FC<ShuffleChoicesOptionProps> = ({
  onShuffle,
  model,
}: ShuffleChoicesOptionProps) => (
  <div className="form-check mb-2">
    <input
      onChange={onShuffle}
      className="form-check-input"
      type="checkbox"
      value=""
      checked={isShuffled(model.authoring.transformations)}
      id="shuffle-choices"
    />
    <label className="form-check-label" htmlFor="shuffle-choices">
      Shuffle answer choices
    </label>
  </div>
);

export function addOrRemove<T>(item: T, list: T[]) {
  if (list.find((x) => x === item)) {
    return remove(item, list);
  }
  return list.push(item);
}

export function remove<T>(item: T, list: T[]) {
  const index = list.findIndex((x) => x === item);
  if (index > -1) {
    list.splice(index, 1);
  }
}

export function setDifference<T>(subtractedFrom: T[], toSubtract: T[]) {
  return subtractedFrom.filter((x) => !toSubtract.includes(x));
}

export function setUnion<T>(list1: T[], list2: T[]) {
  return [...list2.reduce((acc, curr) => acc.add(curr), new Set(list1))];
}

export const castPartId = (partId: string | number): PartId => `${partId}`;
