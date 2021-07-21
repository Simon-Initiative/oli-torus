import { ActivityState, ChoiceId } from 'components/activities/types';
import { Maybe } from 'tsmonad';

// Activity delivery components have an `input` string which is the persisted value
// of a student's entry saved with `onSaveActivity` or submitted with
// `onSubmitActivity`. These functions convert between the `input` string and the
// `selection` which is a `ChoiceId[]` that is used directly by the delivery components.
export const selectionToInput = (selection: ChoiceId[]) => selection.join(' ');
export const inputToSelection = (input: string): ChoiceId[] =>
  input.split(' ').reduce((ids, id) => ids.concat([id]), [] as ChoiceId[]);
// An `ActivityState` only has an input if it has been saved or submitted
export const safelySelectInput = (activityState: ActivityState | undefined): Maybe<string> =>
  Maybe.maybe(activityState?.parts[0]?.response?.input);

export const initialSelection = (
  activityState: ActivityState | undefined,
  defaultSelection: ChoiceId[] = [],
): ChoiceId[] =>
  safelySelectInput(activityState).caseOf({
    just: inputToSelection,
    nothing: () => defaultSelection,
  });

// Is an activity evaluation correct? This does not support partial credit.
export const isCorrect = (activityState: ActivityState) => activityState.score !== 0;
