import { render, fireEvent, screen } from '@testing-library/react';
import React from 'react';
import { defaultDeliveryElementProps } from '../utils/activity_mocks';
import { act } from 'react-dom/test-utils';
import '@testing-library/jest-dom';
import { defaultMCModel } from 'components/activities/multiple_choice/utils';
import { MultipleChoiceComponent } from 'components/activities/multiple_choice/MultipleChoiceDelivery';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { activityDeliverySlice } from 'data/activities/DeliveryState';
import { DeliveryElementProvider } from 'components/activities/DeliveryElementProvider';
import { makeHint } from 'components/activities/types';
import { defaultActivityState } from 'data/activities/utils';

describe('multiple choice delivery', () => {
  it('renders ungraded correctly', async () => {
    const model = defaultMCModel();
    model.authoring.parts[0].hints.push(makeHint('Hint 1'));

    const props = {
      model,
      activitySlug: 'activity-slug',
      state: Object.assign(defaultActivityState(model), { hasMoreHints: false }),
      context: {
        graded: false,
        surveyId: null,
        groupId: null,
        userId: 0,
        pageAttemptGuid: '',
        sectionSlug: '',
        bibParams: [],
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

    // expect results to be displayed after submission
    expect(await screen.findAllByLabelText('result')).toHaveLength(1);
    expect(screen.getByLabelText('score')).toHaveTextContent('1');
    expect(screen.getByLabelText('out of')).toHaveTextContent('1');
  });
});
