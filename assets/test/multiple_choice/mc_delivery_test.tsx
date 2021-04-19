import { render, fireEvent, screen } from '@testing-library/react';
import React from 'react';
import { defaultState } from 'components/resource/TestModeHandler';
import { defaultDeliveryElementProps } from '../utils/activity_mocks';
import { act } from 'react-dom/test-utils';
import '@testing-library/jest-dom';
import { defaultMCModel } from 'components/activities/multiple_choice/utils';
import { MultipleChoiceComponent } from 'components/activities/multiple_choice/MultipleChoiceDelivery';

describe('multiple choice delivery', () => {
  it('renders ungraded correctly', async () => {

    const model = defaultMCModel();
    const props = {
      model,
      activitySlug: 'activity-slug',
      state: defaultState(model),
      graded: false,
    };
    const { onSaveActivity, onSubmitActivity } = defaultDeliveryElementProps;

    render(
      <MultipleChoiceComponent
        {...props}
        {...defaultDeliveryElementProps}
        preview={false}
      />,
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

    // expect no submit button
    const submitButton = screen.queryByLabelText('submit');
    expect(submitButton).toBeFalsy();

    // expect 2 choices
    const choices = screen.queryAllByLabelText(/choice [0-9]/);
    expect(choices).toHaveLength(2);

    // expect clicking a choice to submit but not save the activity
    act(() => {
      fireEvent.click(choices[0]);
    });
    expect(onSaveActivity).toHaveBeenCalledTimes(0);
    expect(onSubmitActivity).toHaveBeenCalledTimes(1);
    expect(onSubmitActivity).toHaveBeenCalledWith('guid',
      [{
        attemptGuid: 'guid',
        response: { input: model.choices.map(choice => choice.id)[0] },
      }]);

    // expect results to be displayed after submission
    expect(await screen.findAllByLabelText('result')).toHaveLength(1);
    expect(screen.getByLabelText('score')).toHaveTextContent('1');
    expect(screen.getByLabelText('out of')).toHaveTextContent('1');
  });
});
