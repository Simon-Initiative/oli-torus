import { render, fireEvent, screen } from '@testing-library/react';
import React from 'react';
import { defaultDeliveryElementProps } from '../utils/activity_mocks';
import { act } from 'react-dom/test-utils';
import '@testing-library/jest-dom';
import { defaultMCModel } from 'components/activities/multiple_choice/utils';
import { MultipleChoiceComponent } from 'components/activities/multiple_choice/MultipleChoiceDelivery';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { activityDeliverySlice } from 'data/content/activities/DeliveryState';
import { DeliveryElementProvider } from 'components/activities/DeliveryElement';
import { defaultState } from 'phoenix/activity_bridge';
import { makeHint } from 'components/activities/types';

describe('multiple choice delivery', () => {
  it('renders ungraded correctly', async () => {
    const model = defaultMCModel();
    model.authoring.parts[0].hints.push(makeHint('Hint 1'));

    const defaultActivityState = defaultState(model);;;;
    const props = {
      model,
      activitySlug: 'activity-slug',
      state: Object.assign(defaultActivityState, { hasMoreHints: false }),
      graded: false,
      preview: false,
    };
    const { onSaveActivity, onSubmitActivity } = defaultDeliveryElementProps;
    const store = configureStore({}, activityDeliverySlice.reducer);

    render(
      <Provider store={store}>
        <DeliveryElementProvider {...defaultDeliveryElementProps} {...props}>
          <MultipleChoiceComponent />
        </DeliveryElementProvider>
      </Provider>,
    );

    // expect no hints displayed
    expect(screen.queryAllByLabelText(/hint [0-9]/)).toHaveLength(0);

    // expect hints button
    const requestHintButton = screen.getByLabelText('request hint');
    expect(requestHintButton).toBeTruthy();

    // expect clicking request hint to display a hint
    act(() => {
      fireEvent.click(requestHintButton);
    });
    expect(await screen.findAllByLabelText(/hint [0-9]/)).toHaveLength(1);

    // expect submit button
    const submitButton = screen.queryByLabelText('submit');
    expect(submitButton).toBeTruthy();
    expect(submitButton).toBeDisabled();

    // expect 2 choices
    const choices = screen.queryAllByLabelText(/choice [0-9]/);
    expect(choices).toHaveLength(2);

    // expect clicking a choice to save but not submit the activity
    act(() => {
      fireEvent.click(choices[0]);
    });
    expect(onSaveActivity).toHaveBeenCalledTimes(1);
    expect(onSaveActivity).toHaveBeenCalledWith(defaultActivityState.attemptGuid, [
      {
        attemptGuid: '1',
        response: { input: model.choices.map((choice) => choice.id)[0] },
      },
    ]);
    expect(onSubmitActivity).toHaveBeenCalledTimes(0);

    expect(submitButton).toBeEnabled();

    act(() => {
      if (submitButton) {
        fireEvent.click(submitButton);
      }
    });

    expect(onSubmitActivity).toHaveBeenCalledTimes(1);
    expect(onSubmitActivity).toHaveBeenCalledWith(defaultActivityState.attemptGuid, [
      {
        attemptGuid: '1',
        response: { input: model.choices.map((choice) => choice.id)[0] },
      },
    ]);

    // expect results to be displayed after submission
    expect(await screen.findAllByLabelText('result')).toHaveLength(1);
    expect(screen.getByLabelText('score')).toHaveTextContent('1');
    expect(screen.getByLabelText('out of')).toHaveTextContent('1');
  });
});
