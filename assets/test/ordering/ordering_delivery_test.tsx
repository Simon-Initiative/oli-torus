import React from 'react';
import { act } from 'react-dom/test-utils';
import { Provider } from 'react-redux';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { DeliveryElementProvider } from 'components/activities/DeliveryElementProvider';
import { OrderingComponent } from 'components/activities/ordering/OrderingDelivery';
import { defaultOrderingModel } from 'components/activities/ordering/utils';
import { makeHint } from 'components/activities/types';
import { activityDeliverySlice } from 'data/activities/DeliveryState';
import { defaultActivityState } from 'data/activities/utils';
import { configureStore } from 'state/store';
import { defaultDeliveryElementProps } from '../utils/activity_mocks';

describe('ordering delivery', () => {
  it('renders ungraded correctly', async () => {
    const model = defaultOrderingModel();
    model.authoring.parts[0].hints.push(makeHint('Hint 1'));
    const props = {
      model,
      activitySlug: 'activity-slug',
      state: Object.assign(defaultActivityState(model), { hasMoreHints: false }),
      context: {
        batchScoring: true,
        oneAtATime: false,
        ordinal: 1,
        maxAttempts: 1,
        scoringStrategyId: 1,
        graded: false,
        surveyId: null,
        groupId: null,
        userId: 0,
        pageAttemptGuid: '',
        sectionSlug: '',
        projectSlug: '',
        bibParams: [],
        showFeedback: true,
        renderPointMarkers: false,
        isAnnotationLevel: false,
        variables: {},
        pageLinkParams: {},
        allowHints: false,
      },
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

    expect(onSubmitActivity).toHaveBeenCalledWith(props.state.attemptGuid, [
      {
        attemptGuid: '1',
        response: { input: model.choices.map((choice) => choice.id).join(' ') },
      },
    ]);

    // expect results to be displayed after submission
    expect(await screen.findAllByLabelText('result')).toHaveLength(1);
  });
});
