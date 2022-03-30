import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import {
  ActivityModelSchema,
  ActivityState,
  Part,
  PartId,
  PartState,
} from 'components/activities/types';
import { PartInputs, StudentInput } from 'data/activities/DeliveryState';
import { Maybe } from 'tsmonad';
import { removeEmpty } from 'utils/common';
import guid from 'utils/guid';

// Activity delivery components have an `input` string which is the persisted value
// of a student's entry saved with `onSaveActivity` or submitted with
// `onSubmitActivity`. These functions convert between the `input` string and the
// `selection` which is a `ChoiceId[]` that is used directly by the delivery components.
export const studentInputToString = (studentInput: StudentInput): string => studentInput.join(' ');
export const stringToStudentInput = (input: string): StudentInput =>
  input.split(' ').reduce((ids, id) => ids.concat([id]), [] as StudentInput);

// An `ActivityState` only has an input if it has been saved or submitted.
// Each activity part may have an input.
export const safelySelectInputs = (activityState: ActivityState | undefined): Maybe<PartInputs> => {
  const partInputs = activityState?.parts.filter((part) => !!part?.response?.input);
  if (!partInputs) return Maybe.nothing();

  return Maybe.maybe(activityState).lift((state) =>
    state.parts.reduce((acc, partState) => {
      const input = partState.response?.input;
      acc[String(partState.partId)] = typeof input === 'string' ? stringToStudentInput(input) : [];
      return acc;
    }, {} as PartInputs),
  );
};

export const safelySelectStringInputs = (
  activityState: ActivityState | undefined,
): Maybe<PartInputs> => {
  const partInputs = activityState?.parts.filter((part) => !!part?.response?.input);
  if (!partInputs) return Maybe.nothing();

  return Maybe.maybe(activityState).lift((state) =>
    state.parts.reduce((acc, partState) => {
      const input = partState.response?.input;
      acc[String(partState.partId)] = [input];
      return acc;
    }, {} as PartInputs),
  );
};

export const initialPartInputs = (
  activityState: ActivityState | undefined,
  defaultPartInputs: PartInputs = { [DEFAULT_PART_ID]: [] },
): PartInputs => {
  const savedPartInputs = activityState?.parts
    .filter((part) => part?.response?.input !== undefined)
    .reduce((acc, part) => {
      acc[part.partId] = part.response.input;
      return acc;
    }, {} as Record<PartId, string>);

  if (!savedPartInputs) return defaultPartInputs;

  return Object.entries(defaultPartInputs).reduce((acc, partInput) => {
    const [partId, defaultInput] = partInput;
    if (savedPartInputs[partId]) {
      acc[partId] = stringToStudentInput(savedPartInputs[partId]);
      return acc;
    }
    acc[partId] = defaultInput;
    return acc;
  }, {} as PartInputs);
};

// Is an activity evaluation correct? This does not support partial credit.
export const isCorrect = (activityState: ActivityState) => activityState.score !== 0;

export const defaultActivityState = (model: ActivityModelSchema): ActivityState => {
  const parts: PartState[] = model.authoring.parts.map((p: Part) => ({
    attemptNumber: 1,
    attemptGuid: p.id,
    dateEvaluated: null,
    dateSubmitted: null,
    score: null,
    outOf: null,
    response: null,
    feedback: null,
    hints: [],
    hasMoreHints: removeEmpty(p.hints).length > 0,
    hasMoreAttempts: true,
    partId: p.id,
  }));

  return {
    attemptNumber: 1,
    attemptGuid: guid(),
    dateEvaluated: null,
    dateSubmitted: null,
    score: null,
    outOf: null,
    hasMoreAttempts: true,
    parts,
    hasMoreHints: false,
  };
};
