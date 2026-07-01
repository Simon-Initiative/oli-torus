import React from 'react';
import { act } from 'react-dom/test-utils';
import { Provider } from 'react-redux';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { createStore } from 'redux';
import {
  ResetModal,
  ScoreAsYouGoSubmitReset,
  buildConfirmMessage,
  getDisplayedScore,
} from 'components/activities/common/ScoreAsYouGoSubmitReset';
import { ActivityDeliveryState } from 'data/activities/DeliveryState';

const buildState = (
  scoringStrategyId: number,
  overrides: Partial<ActivityDeliveryState['activityContext']> = {},
): ActivityDeliveryState =>
  ({
    model: {},
    activityContext: {
      graded: true,
      batchScoring: false,
      oneAtATime: false,
      maxAttempts: 4,
      scoringStrategyId,
      replacementStrategy: 'none',
      aggregateScore: 7,
      aggregateOutOf: 8,
      aggregateIncludesCurrentAttempt: true,
      ordinal: 1,
      sectionSlug: '',
      projectSlug: '',
      userId: 1,
      groupId: null,
      surveyId: null,
      bibParams: [],
      pageAttemptGuid: '',
      showFeedback: true,
      renderPointMarkers: false,
      isAnnotationLevel: true,
      variables: {},
      pageLinkParams: {},
      allowHints: false,
      ...overrides,
    },
    attemptState: {
      attemptGuid: 'attempt-guid',
      attemptNumber: 2,
      dateEvaluated: new Date(),
      dateSubmitted: new Date(),
      score: 6,
      outOf: 8,
      parts: [],
      hasMoreAttempts: true,
      hasMoreHints: false,
      groupId: null,
    },
    partState: {},
  } as ActivityDeliveryState);

describe('ScoreAsYouGoSubmitReset', () => {
  it('renders average strategy score impact and remaining attempts', () => {
    render(<>{buildConfirmMessage(buildState(1))}</>);

    expect(screen.getByText(/Your current score:/).closest('p')).toHaveTextContent(
      'Your current score: 7/8 points (average of 2 attempts)',
    );
    expect(screen.getByText(/Attempts Remaining:/)).toHaveTextContent('Attempts Remaining: 2');
    expect(screen.getByText(/Your score is the average/)).toHaveTextContent(
      'Your score is the average of all attempts. Scoring below 7/8 will lower your score.',
    );
  });

  it('renders best strategy score protection and last-attempt language', () => {
    render(<>{buildConfirmMessage(buildState(2, { maxAttempts: 3 }))}</>);

    expect(screen.getByText(/Your best score:/).closest('p')).toHaveTextContent(
      'Your best score: 7/8 points (2 attempts)',
    );
    expect(screen.getByText(/Attempts Remaining:/).closest('p')).toHaveTextContent(
      'Attempts Remaining: 1 (last attempt)',
    );
    expect(screen.getByText(/Your best score will be kept/)).toHaveTextContent(
      'a lower score will not reduce your current best.',
    );
  });

  it('renders most-recent replacement language and omits unlimited attempts remaining', () => {
    render(
      <>
        {buildConfirmMessage(
          buildState(3, {
            maxAttempts: 0,
            replacementStrategy: 'dynamic',
          }),
        )}
      </>,
    );

    expect(screen.queryByText(/Attempts Remaining:/)).not.toBeInTheDocument();
    expect(screen.getByText(/Resetting may give you/)).toHaveTextContent(
      'Resetting may give you a new version of this question and count as another attempt.',
    );
    expect(screen.getByText(/Your next attempt will replace/)).toHaveTextContent(
      'Your next attempt will replace your current score. Scoring below 7/8 will lower your score.',
    );
  });

  it('derives the new average immediately after a client-side submission', () => {
    const state = buildState(1, {
      aggregateScore: 8,
      aggregateOutOf: 8,
      aggregateIncludesCurrentAttempt: false,
    });
    state.attemptState.score = 6;

    expect(getDisplayedScore(state)).toEqual({ score: 7, outOf: 8 });
  });

  it('does not reset until the confirmation callback is invoked', async () => {
    const state = buildState(1);
    const store = createStore(() => state);
    const onReset = jest.fn().mockResolvedValue(undefined);
    const dispatch = jest.fn();
    window.oliDispatch = dispatch;

    render(
      <Provider store={store}>
        <ScoreAsYouGoSubmitReset mode="delivery" onSubmit={jest.fn()} onReset={onReset} />
      </Provider>,
    );

    fireEvent.click(screen.getByRole('button', { name: /Reset Question/ }));

    expect(onReset).not.toHaveBeenCalled();
    const firstModal = dispatch.mock.calls[0][0].component as React.ReactElement;
    expect(firstModal.type).toBe(ResetModal);

    act(() => firstModal.props.onCancel());
    expect(onReset).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole('button', { name: /Reset Question/ }));
    const secondModal = dispatch.mock.calls[2][0].component as React.ReactElement;

    await act(async () => secondModal.props.onDone());
    expect(onReset).toHaveBeenCalledTimes(1);
  });
});
