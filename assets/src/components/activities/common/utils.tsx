import * as ContentModel from 'data/content/model';
import { Operation, RichText, Transformation } from '../types';
import guid from 'utils/guid';
import React from 'react';
import { Maybe } from 'tsmonad';

export function fromText(text: string): { id: string; content: RichText } {
  return {
    id: guid() + '',
    content: {
      model: [
        ContentModel.create<ContentModel.Paragraph>({
          type: 'p',
          children: [{ text }],
          id: guid() + '',
        }),
      ],
      selection: null,
    },
  };
}

export const makeTransformation = (path: string, operation: Operation): Transformation => ({
  id: guid(),
  path,
  operation,
});

export const isShuffled = (transformations: Transformation[]): boolean =>
  !!transformations.find((xform) => xform.operation === Operation.shuffle);

export const toggleAnswerChoiceShuffling = () => {
  return (model: { authoring: { transformations: Transformation[] } }): void => {
    const transformations = model.authoring.transformations;

    isShuffled(transformations)
      ? (model.authoring.transformations = transformations.filter(
          (xform) => xform.operation !== Operation.shuffle,
        ))
      : model.authoring.transformations.push(makeTransformation('choices', Operation.shuffle));
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
