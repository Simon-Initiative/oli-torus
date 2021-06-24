import { render, fireEvent, screen } from '@testing-library/react';
import React from 'react';
import { defaultState } from 'components/resource/TestModeHandler';
import { defaultCATAModel } from 'components/activities/check_all_that_apply/utils';
import { CheckAllThatApplyComponent } from 'components/activities/check_all_that_apply/CheckAllThatApplyDelivery';
import { defaultDeliveryElementProps } from '../utils/activity_mocks';
import { act } from 'react-dom/test-utils';
import '@testing-library/jest-dom';
import { configureStore } from 'state/store';
import { slice } from 'data/content/activities/DeliveryState';
import { Provider } from 'react-redux';

describe('check all that apply delivery', () => {
  it('renders ungraded correctly', async () => {
    const model = defaultCATAModel();
    const props = {
      model,
      activitySlug: 'activity-slug',
      state: defaultState(model),
      graded: false,
    };
    const { onSaveActivity, onSubmitActivity } = defaultDeliveryElementProps;
    const store = configureStore({}, slice.reducer);

    render(
      <Provider store={store}>
        <CheckAllThatApplyComponent {...props} {...defaultDeliveryElementProps} preview={false} />
      </Provider>,
    );

    // expect 2 choices
    const choices = screen.queryAllByLabelText(/choice [0-9]/);
    expect(choices).toHaveLength(2);

    // expect clicking a choice to save the activity
    act(() => {
      fireEvent.click(choices[0]);
    });
    expect(onSaveActivity).toHaveBeenCalledTimes(1);
    expect(onSaveActivity).toHaveBeenCalledWith('guid', [
      {
        attemptGuid: 'guid',
        response: { input: model.choices.map((choice) => choice.id)[0] },
      },
    ]);

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
    const submitButton = screen.getByLabelText('submit');
    expect(submitButton).toBeTruthy();

    // expect clicking the submit button to submit
    act(() => {
      fireEvent.click(submitButton);
    });
    expect(onSubmitActivity).toHaveBeenCalledTimes(1);
    expect(onSubmitActivity).toHaveBeenCalledWith('guid', [
      {
        attemptGuid: 'guid',
        response: { input: model.choices.map((choice) => choice.id)[0] },
      },
    ]);

    // expect results to be displayed after submission
    expect(await screen.findAllByLabelText('result')).toHaveLength(1);
    expect(screen.getByLabelText('score')).toHaveTextContent('1');
    expect(screen.getByLabelText('out of')).toHaveTextContent('1');
  });
});
