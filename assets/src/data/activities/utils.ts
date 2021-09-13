import { ActivityState, ChoiceId, PartId } from 'components/activities/types';
import { ID } from 'data/content/model';
import { Maybe } from 'tsmonad';

// Activity delivery components have an `input` string which is the persisted value
// of a student's entry saved with `onSaveActivity` or submitted with
// `onSubmitActivity`. These functions convert between the `input` string and the
// `selection` which is a `ChoiceId[]` that is used directly by the delivery components.
export const selectionToInput = (selection: ChoiceId[]) => selection.join(' ');
export const inputToSelections = (partInputs: Map<ID, string>): Map<PartId, string[]> =>
  new Map(
    [...partInputs].map(([partId, input]) => [
      partId,
      input.split(' ').reduce((ids, id) => ids.concat([id]), [] as ChoiceId[]),
    ]),
  );

// An `ActivityState` only has an input if it has been saved or submitted.
// Each activity part may have an input.
export const safelySelectInputs = (
  activityState: ActivityState | undefined,
): Maybe<Map<PartId, string>> =>
  Maybe.maybe(activityState).lift((state) =>
    state.parts.reduce(
      (acc, partState) => acc.set(partState.partId, partState.response.input),
      new Map(),
    ),
  );

export const initialSelections = (
  activityState: ActivityState | undefined,
  defaultSelections?: Map<PartId, string[]>,
): Map<PartId, string[]> =>
  safelySelectInputs(activityState).caseOf({
    just: inputToSelections,
    nothing: () =>
      defaultSelections ||
      new Map(activityState?.parts.map((partState) => [String(partState.partId), []])),
  });

// Is an activity evaluation correct? This does not support partial credit.
export const isCorrect = (activityState: ActivityState) => activityState.score !== 0;
