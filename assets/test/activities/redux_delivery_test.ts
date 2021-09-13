import { defaultCATAModel } from 'components/activities/check_all_that_apply/utils';
import { defaultDeliveryElementProps } from '../utils/activity_mocks';
import '@testing-library/jest-dom';
import { configureStore } from 'state/store';
import { activityDeliverySlice, setSelection } from 'data/activities/DeliveryState';
import { defaultState } from 'phoenix/activity_bridge';
import { makeHint } from 'components/activities/types';
import { Dispatch, Store } from 'redux';
import { ActivityDeliveryState, initializeState } from 'data/activities/DeliveryState';
import { initialPartInputs, inputToSelections, selectionToInput } from 'data/activities/utils';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';

describe('activity delivery state management', () => {
  const model = defaultCATAModel();
  model.authoring.parts[0].hints.push(makeHint('Hint 1'));
  const defaultActivityState = defaultState(model);
  const props = {
    model,
    activitySlug: 'activity-slug',
    state: Object.assign(defaultActivityState, { hasMoreHints: false }),
    graded: false,
    preview: false,
  };
  const { onSaveActivity } = defaultDeliveryElementProps;
  const store: Store<ActivityDeliveryState> = configureStore({}, activityDeliverySlice.reducer);
  const dispatch: Dispatch<any> = store.dispatch;

  it('can initialize state', () => {
    dispatch(initializeState(props.state, initialPartInputs(props.state)));
    expect(store.getState().attemptState).toEqual(props.state);
    const partState = store.getState().partState.get(DEFAULT_PART_ID);
    expect(partState).toBeTruthy();
    expect(partState?.hintsShown).toEqual(props.state.parts[0].hints);
    expect(partState?.hasMoreHints).toBe(true);
    expect(partState?.studentInput).toEqual([]);
  });

  it('can select single choices', () => {
    dispatch(initializeState(props.state, initialPartInputs(props.state)));
    dispatch(setSelection(DEFAULT_PART_ID, model.choices[0].id, onSaveActivity, 'single'));
    expect(store.getState().partState.get(DEFAULT_PART_ID)?.studentInput).toEqual([
      model.choices[0].id,
    ]);
  });

  it('can select multiple choices', () => {
    dispatch(initializeState(props.state, initialPartInputs(props.state)));
    dispatch(setSelection(DEFAULT_PART_ID, model.choices[0].id, onSaveActivity, 'multiple'));
    dispatch(setSelection(DEFAULT_PART_ID, model.choices[1].id, onSaveActivity, 'multiple'));
    expect(store.getState().partState.get(DEFAULT_PART_ID)?.studentInput).toEqual([
      model.choices[0].id,
      model.choices[1].id,
    ]);
  });

  it('can convert input to selections used by components and back', () => {
    let selection = [model.choices[0].id];
    expect(selectionToInput(selection)).toEqual(model.choices[0].id);
    selection = model.choices.map((c) => c.id);
    expect(selectionToInput(selection)).toEqual(`${model.choices[0].id} ${model.choices[1].id}`);

    let input = '123';
    expect(inputToSelections(new Map().set(DEFAULT_PART_ID, [input])).get(DEFAULT_PART_ID)).toEqual(
      ['123'],
    );
    input = '123 456';
    expect(inputToSelections(new Map().set(DEFAULT_PART_ID, [input]).get(DEFAULT_PART_ID))).toEqual(
      ['123', '456'],
    );
  });
});
