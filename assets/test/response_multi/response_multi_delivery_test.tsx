import React from 'react';
import { Provider } from 'react-redux';
import '@testing-library/jest-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import {
  ActivityContext,
  EvaluationResponse,
  PartActivityResponse,
} from 'components/activities/DeliveryElement';
import { DeliveryElementProvider } from 'components/activities/DeliveryElementProvider';
import { ResponseMultiInputComponent } from 'components/activities/response_multi/ResponseMultiInputDelivery';
import { ResponseMultiInputSchema } from 'components/activities/response_multi/schema';
import { makeFeedback, makeHint, makePart, makeResponse } from 'components/activities/types';
import { activityDeliverySlice } from 'data/activities/DeliveryState';
import { defaultActivityState } from 'data/activities/utils';
import { configureStore } from 'state/store';

describe('response multi delivery', () => {
  it('preserves the latest sibling dropdown value across evaluated per-part submissions', async () => {
    const partId = 'part-1';
    const firstInputId = 'input-first';
    const secondInputId = 'input-second';

    const graphChoiceA = 'graph-a';
    const graphChoiceB = 'graph-b';
    const orderChoiceX = 'order-x';
    const orderChoiceY = 'order-y';

    const model: ResponseMultiInputSchema = {
      stem: {
        id: 'stem-1',
        content: [
          {
            type: 'p',
            id: 'p-1',
            children: [
              { text: 'Graph: ' },
              { type: 'input_ref', id: firstInputId, children: [{ text: '' }] },
              { text: ' Order: ' },
              { type: 'input_ref', id: secondInputId, children: [{ text: '' }] },
            ],
          },
        ],
      },
      choices: [
        { id: graphChoiceA, content: [{ type: 'p', id: 'c1', children: [{ text: '1/[XY2]' }] }] },
        { id: graphChoiceB, content: [{ type: 'p', id: 'c2', children: [{ text: 'ln[XY2]' }] }] },
        { id: orderChoiceX, content: [{ type: 'p', id: 'c3', children: [{ text: 'zero' }] }] },
        { id: orderChoiceY, content: [{ type: 'p', id: 'c4', children: [{ text: 'second' }] }] },
      ],
      submitPerPart: true,
      multInputsPerPart: true,
      inputs: [
        {
          id: firstInputId,
          inputType: 'dropdown',
          partId,
          choiceIds: [graphChoiceA, graphChoiceB],
        },
        {
          id: secondInputId,
          inputType: 'dropdown',
          partId,
          choiceIds: [orderChoiceX, orderChoiceY],
        },
      ],
      authoring: {
        parts: [
          makePart(
            [
              makeResponse(
                `input_ref_${firstInputId} like {.*} && input_ref_${secondInputId} like {.*}`,
                1,
              ),
            ],
            [makeHint('')],
            partId,
            [firstInputId, secondInputId],
          ),
        ],
        targeted: [],
        transformations: [],
        previewText: 'Graph and order',
      },
    };

    const state = defaultActivityState(model);
    const initialPartAttemptGuid = state.parts[0].attemptGuid;

    const context: ActivityContext = {
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
    };

    let resetCount = 0;

    const onSaveActivity = jest.fn().mockResolvedValue({ type: 'success' });
    const onSubmitActivity = jest.fn().mockResolvedValue({ type: 'success', actions: [] });
    const onResetActivity = jest.fn();
    const onRequestHint = jest.fn();
    const onSavePart = jest.fn();

    const onResetPart = jest
      .fn<Promise<PartActivityResponse>, [string, string]>()
      .mockImplementation(async () => {
        resetCount += 1;
        return {
          type: 'success',
          attemptState: {
            attemptGuid: `reset-attempt-${resetCount}`,
            attemptNumber: resetCount + 1,
            dateEvaluated: null,
            dateSubmitted: null,
            score: null,
            outOf: null,
            response: null,
            feedback: null,
            explanation: null,
            hints: [],
            hasMoreAttempts: true,
            hasMoreHints: false,
            partId,
          },
        };
      });

    const onSubmitPart = jest
      .fn<Promise<EvaluationResponse>, [string, string, { input: string }]>()
      .mockImplementation(async (_attemptGuid, partAttemptGuid) => ({
        type: 'success',
        actions: [
          {
            type: 'FeedbackAction',
            attempt_guid: partAttemptGuid,
            part_id: partId,
            out_of: 1,
            score: 1,
            show_page: null,
            feedback: makeFeedback('ok'),
            explanation: null,
          },
        ],
      }));

    const onSubmitEvaluations = jest.fn().mockResolvedValue({ type: 'success', actions: [] });

    const store = configureStore({}, activityDeliverySlice.reducer);

    render(
      <Provider store={store}>
        <DeliveryElementProvider
          model={model}
          state={state}
          context={context}
          mode="delivery"
          onSaveActivity={onSaveActivity}
          onSubmitActivity={onSubmitActivity}
          onResetActivity={onResetActivity}
          onRequestHint={onRequestHint}
          onSavePart={onSavePart}
          onSubmitPart={onSubmitPart}
          onResetPart={onResetPart}
          onSubmitEvaluations={onSubmitEvaluations}
        >
          <ResponseMultiInputComponent />
        </DeliveryElementProvider>
      </Provider>,
    );

    const selects = screen.getAllByLabelText('Select answer');
    const firstDropdown = selects[0];
    const secondDropdown = selects[1];

    fireEvent.change(firstDropdown, { target: { value: graphChoiceA } });
    fireEvent.change(secondDropdown, { target: { value: orderChoiceX } });

    await waitFor(() => expect(onSubmitPart).toHaveBeenCalledTimes(1));

    fireEvent.change(secondDropdown, { target: { value: orderChoiceY } });
    await waitFor(() => expect(onSubmitPart).toHaveBeenCalledTimes(2));
    await waitFor(() => expect(onResetPart).toHaveBeenCalledTimes(1));

    fireEvent.change(firstDropdown, { target: { value: graphChoiceB } });
    await waitFor(() => expect(onSubmitPart).toHaveBeenCalledTimes(3));
    await waitFor(() => expect(onResetPart).toHaveBeenCalledTimes(2));

    const finalSubmissionInput = onSubmitPart.mock.calls[2][2].input;
    const parsed = JSON.parse(finalSubmissionInput);

    expect(parsed).toEqual({
      [firstInputId]: graphChoiceB,
      [secondInputId]: orderChoiceY,
    });

    expect(onSubmitPart.mock.calls[0][1]).toBe(initialPartAttemptGuid);
    expect(onSubmitPart.mock.calls[1][1]).toBe('reset-attempt-1');
    expect(onSubmitPart.mock.calls[2][1]).toBe('reset-attempt-2');
  });
});
