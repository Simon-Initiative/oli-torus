import React from 'react';
import { act } from 'react-dom/test-utils';
import { Provider } from 'react-redux';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { DeliveryElementProvider } from 'components/activities/DeliveryElementProvider';
import { MultipleChoiceComponent } from 'components/activities/multiple_choice/MultipleChoiceDelivery';
import { defaultMCModel } from 'components/activities/multiple_choice/utils';
import { makeHint } from 'components/activities/types';
import { activityDeliverySlice } from 'data/activities/DeliveryState';
import { defaultActivityState } from 'data/activities/utils';
import { configureStore } from 'state/store';
import { defaultDeliveryElementProps } from '../utils/activity_mocks';

describe('multiple choice delivery', () => {
  it('renders ungraded correctly', async () => {
    const model = defaultMCModel();
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

    // expect 2 choices
    const choices = screen.queryAllByLabelText(/choice [0-9]/);
    expect(choices).toHaveLength(2);

    // expect clicking a choice to save but not submit the activity
    act(() => {
      fireEvent.click(choices[0]);
    });
    expect(onSaveActivity).toHaveBeenCalledTimes(0);
    expect(onSubmitActivity).toHaveBeenCalledTimes(1);

    expect(onSubmitActivity).toHaveBeenCalledTimes(1);
    expect(onSubmitActivity).toHaveBeenCalledWith(props.state.attemptGuid, [
      {
        attemptGuid: '1',
        response: { input: model.choices.map((choice) => choice.id)[0] },
      },
    ]);

    expect(requestHintButton).toBeTruthy();

    // expect results to be displayed after submission
    expect(await screen.findAllByLabelText('result')).toHaveLength(1);
  });
});
