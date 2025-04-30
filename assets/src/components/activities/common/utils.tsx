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
      className="inline-flex"
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M6.87266 14C6.25586 13.8576 5.66348 13.6219 5.11521 13.3008M9.70724 1.33337C11.1161 1.66102 12.3741 2.46604 13.275 3.61661C14.176 4.76718 14.6667 6.19514 14.6667 7.6667C14.6667 9.13826 14.176 10.5662 13.275 11.7168C12.3741 12.8674 11.1161 13.6724 9.70724 14M3.03106 11.3417C2.64449 10.7699 2.3509 10.1383 2.16155 9.47139M2 6.58432C2.11338 5.89882 2.33165 5.2494 2.63778 4.65409L2.75754 4.43401M4.68079 2.31184C5.34384 1.84707 6.08768 1.51501 6.87263 1.33337"
        stroke="#0FB863"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M6.81416 5.79814L4.33305 6.15786L4.28911 6.16681C4.22258 6.18447 4.16194 6.21947 4.11337 6.26823C4.06479 6.31699 4.03003 6.37777 4.01263 6.44437C3.99523 6.51096 3.99582 6.58098 4.01433 6.64727C4.03284 6.71356 4.06861 6.77375 4.118 6.8217L5.91544 8.57131L5.49155 11.0427L5.4865 11.0855C5.48242 11.1543 5.49671 11.2229 5.52789 11.2844C5.55908 11.3459 5.60603 11.3979 5.66396 11.4353C5.72189 11.4726 5.7887 11.4939 5.85755 11.497C5.92641 11.5 5.99484 11.4847 6.05583 11.4526L8.27483 10.2859L10.4888 11.4526L10.5277 11.4705C10.5919 11.4958 10.6616 11.5035 10.7298 11.4929C10.798 11.4824 10.8621 11.4538 10.9156 11.4103C10.9691 11.3668 11.0101 11.3098 11.0343 11.2452C11.0585 11.1806 11.0651 11.1107 11.0534 11.0427L10.6292 8.57131L12.4274 6.82131L12.4577 6.78825C12.5011 6.73488 12.5295 6.67098 12.5401 6.60306C12.5507 6.53514 12.5431 6.46562 12.518 6.40159C12.493 6.33756 12.4515 6.28131 12.3976 6.23856C12.3438 6.19582 12.2796 6.1681 12.2116 6.15825L9.73044 5.79814L8.62133 3.55036C8.58924 3.48524 8.53955 3.4304 8.4779 3.39205C8.41625 3.3537 8.3451 3.33337 8.2725 3.33337C8.19989 3.33337 8.12874 3.3537 8.06709 3.39205C8.00544 3.4304 7.95576 3.48524 7.92366 3.55036L6.81416 5.79814Z"
        fill="#0FB863"
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
