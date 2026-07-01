import React from 'react';
import { ShortAnswerModelSchema } from '../short_answer/schema';
import {
  HasPerPartSubmissionOption,
  PartId,
  Transform,
  Transformation,
  makeTransformation,
} from '../types';

export const ScoreAsYouGoIcon = () => {
  return (
    <svg
      className="inline-flex text-Text-text-accent-green"
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M6.87266 14.0007C6.25586 13.8582 5.66348 13.6225 5.11521 13.3014M9.70724 1.33398C11.1161 1.66163 12.3741 2.46665 13.275 3.61722C14.176 4.76779 14.6667 6.19575 14.6667 7.66731C14.6667 9.13887 14.176 10.5668 13.275 11.7174C12.3741 12.868 11.1161 13.673 9.70724 14.0006M3.03106 11.3423C2.64449 10.7705 2.3509 10.1389 2.16155 9.472M2 6.58493C2.11338 5.89943 2.33165 5.25001 2.63778 4.6547L2.75754 4.43462M4.68079 2.31245C5.34384 1.84768 6.08768 1.51562 6.87263 1.33398"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M6.81416 5.79875L4.33305 6.15847L4.28911 6.16742C4.22258 6.18508 4.16194 6.22008 4.11337 6.26884C4.06479 6.3176 4.03003 6.37839 4.01263 6.44498C3.99523 6.51157 3.99582 6.58159 4.01433 6.64788C4.03284 6.71417 4.06861 6.77436 4.118 6.82231L5.91544 8.57192L5.49155 11.0433L5.4865 11.0861C5.48242 11.1549 5.49671 11.2235 5.52789 11.285C5.55908 11.3465 5.60603 11.3985 5.66396 11.4359C5.72189 11.4732 5.7887 11.4945 5.85755 11.4976C5.92641 11.5006 5.99484 11.4853 6.05583 11.4532L8.27483 10.2865L10.4888 11.4532L10.5277 11.4711C10.5919 11.4964 10.6616 11.5041 10.7298 11.4935C10.798 11.483 10.8621 11.4545 10.9156 11.4109C10.9691 11.3674 11.0101 11.3104 11.0343 11.2458C11.0585 11.1812 11.0651 11.1113 11.0534 11.0433L10.6292 8.57192L12.4274 6.82192L12.4577 6.78886C12.5011 6.73549 12.5295 6.67159 12.5401 6.60367C12.5507 6.53575 12.5431 6.46623 12.518 6.4022C12.493 6.33817 12.4515 6.28192 12.3976 6.23917C12.3438 6.19643 12.2796 6.16872 12.2116 6.15886L9.73044 5.79875L8.62133 3.55097C8.58924 3.48585 8.53955 3.43101 8.4779 3.39266C8.41625 3.35431 8.3451 3.33398 8.2725 3.33398C8.19989 3.33398 8.12874 3.35431 8.06709 3.39266C8.00544 3.43101 7.95576 3.48585 7.92366 3.55097L6.81416 5.79875Z"
        fill="currentColor"
      />
    </svg>
  );
};

export const isShuffled = (transformations: Transformation[], partId?: string): boolean =>
  partId
    ? !!transformations.find(
        (xform) => xform.operation === Transform.shuffle && xform.partId === partId,
      )
    : !!transformations.find((xform) => xform.operation === Transform.shuffle);

export const toggleAnswerChoiceShuffling = (partId?: string) => {
  return (model: { authoring: { transformations: Transformation[] } }): void => {
    const transformations = model.authoring.transformations;

    isShuffled(transformations, partId)
      ? (model.authoring.transformations = transformations.filter(
          (xform) => !(xform.operation === Transform.shuffle && xform.partId === partId),
        ))
      : model.authoring.transformations.push(
          makeTransformation('choices', Transform.shuffle, true, partId),
        );
  };
};

export const togglePerPartSubmissionOption = () => {
  return (model: HasPerPartSubmissionOption): void => {
    model.submitPerPart =
      model.submitPerPart === undefined || model.submitPerPart === false ? true : false;
  };
};

export const toggleSubmitAndCompareOption = () => {
  return (model: ShortAnswerModelSchema): void => {
    model.submitAndCompare = !model.submitAndCompare;
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

export const formatDate = (date: string) => {
  const d = new Date(date);
  return `${d.toLocaleDateString()} ${d.toLocaleTimeString()}`;
};
