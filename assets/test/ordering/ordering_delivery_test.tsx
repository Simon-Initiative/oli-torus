import { render, fireEvent, screen } from '@testing-library/react';
import React from 'react';
import { defaultState } from 'components/resource/TestModeHandler';
import { defaultDeliveryElementProps } from '../utils/activity_mocks';
import { act } from 'react-dom/test-utils';
import '@testing-library/jest-dom';
import { defaultOrderingModel } from 'components/activities/ordering/utils';
import { OrderingComponent } from 'components/activities/ordering/OrderingDelivery';
import { makeHint } from 'components/activities/types';
import { configureStore } from 'state/store';
import { activityDeliverySlice } from 'data/content/activities/DeliveryState';
import { Provider } from 'react-redux';
import { DeliveryElementProvider } from 'components/activities/DeliveryElement';
import { dispatch } from 'utils/test_utils';

describe('ordering delivery', () => {
  it('renders ungraded correctly', async () => {
    const model = defaultOrderingModel();
    model.authoring.parts[0].hints.push(makeHint('Hint 1'));
    const defaultActivityState = defaultState(model);
    const props = {
      model,
      activitySlug: 'activity-slug',
      state: Object.assign(defaultActivityState, { hasMoreHints: false }),
      graded: false,
      preview: false,
    };
    const { onSubmitActivity } = defaultDeliveryElementProps;
    const store = configureStore({}, activityDeliverySlice.reducer);

    render(
      <Provider store={store}>
        <DeliveryElementProvider {...defaultDeliveryElementProps} {...props}>
          <OrderingComponent />
        </DeliveryElementProvider>
      </Provider>,
    );

    // expect 2 choices
    const choices = screen.queryAllByLabelText(/choice [0-9]/);
    expect(choices).toHaveLength(2);

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

    // expect a submit button
    const submitButton = screen.getByLabelText('submit');
    expect(submitButton).toBeTruthy();

    // expect clicking the submit button to submit with 2 choices selected
    act(() => {
      fireEvent.click(submitButton);
    });

    expect(onSubmitActivity).toHaveBeenCalledWith(defaultActivityState.attemptGuid, [
      {
        attemptGuid: '1',
        response: { input: model.choices.map((choice) => choice.id).join(' ') },
      },
    ]);

    // expect results to be displayed after submission
    expect(await screen.findAllByLabelText('result')).toHaveLength(1);
    expect(screen.getByLabelText('score')).toHaveTextContent('1');
    expect(screen.getByLabelText('out of')).toHaveTextContent('1');
  });
});
