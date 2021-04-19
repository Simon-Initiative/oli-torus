import { render, fireEvent, screen } from '@testing-library/react';
import React from 'react';
import { defaultState } from 'components/resource/TestModeHandler';
import { defaultDeliveryElementProps } from '../utils/activity_mocks';
import { act } from 'react-dom/test-utils';
import '@testing-library/jest-dom';
import { defaultModel } from 'components/activities/short_answer/utils';
import { ShortAnswerComponent } from 'components/activities/short_answer/ShortAnswerDelivery';

describe('multiple choice delivery', () => {
  it('renders ungraded activities correctly', async () => {

    const model = defaultModel();
    const props = {
      model,
      activitySlug: 'activity-slug',
      state: defaultState(model),
      graded: false,
    };
    const { onSaveActivity, onSubmitActivity } = defaultDeliveryElementProps;

    render(
      <ShortAnswerComponent
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

    // enter an input, expect it to save
    act(() => {
      fireEvent.change(screen.getByLabelText('answer submission textbox'), { target: { value: 'answer' } });
    });

    expect(onSaveActivity).toHaveBeenCalledTimes(1);

    // expect a submit button
    const submitButton = screen.getByLabelText('submit');
    expect(submitButton).toBeTruthy();

    // submit and expect a submission
    act(() => {
      fireEvent.click(submitButton);
    });

    expect(onSubmitActivity).toHaveBeenCalledTimes(1);
    expect(onSubmitActivity).toHaveBeenCalledWith('guid',
      [{
        attemptGuid: 'guid',
        response: { input: 'answer' },
      }]);

    // expect results to be displayed after submission
    expect(await screen.findAllByLabelText('result')).toHaveLength(1);
    expect(screen.getByLabelText('score')).toHaveTextContent('1');
    expect(screen.getByLabelText('out of')).toHaveTextContent('1');
  });
});
