import React from 'react';
import { act } from 'react-dom/test-utils';
import { Provider } from 'react-redux';
import '@testing-library/jest-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { ActivityContext } from 'components/activities/DeliveryElement';
import { DeliveryElementProvider } from 'components/activities/DeliveryElementProvider';
import { ShortAnswerComponent } from 'components/activities/short_answer/ShortAnswerDelivery';
import { ShortAnswerActions } from 'components/activities/short_answer/actions';
import { ShortAnswerModelSchema } from 'components/activities/short_answer/schema';
import { defaultModel } from 'components/activities/short_answer/utils';
import { makeHint } from 'components/activities/types';
import { activityDeliverySlice } from 'data/activities/DeliveryState';
import { defaultActivityState } from 'data/activities/utils';
import { configureStore } from 'state/store';
import { dispatch } from 'utils/test_utils';
import { defaultDeliveryElementProps } from '../utils/activity_mocks';

jest.mock('gleam/torusExpression', () => ({
  validateMathExpressionSyntax: (expression: string) =>
    expression === 'not a number' || expression.includes('//') || expression.endsWith('(')
      ? { status: 'invalid', debug: 'invalid expression' }
      : { status: 'valid', debug: 'valid expression' },
  previewMathExpressionSyntax: (expression: string, kind: 'expression' | 'quantity') =>
    expression === 'not a number' || expression.includes('//') || expression.endsWith('(')
      ? { status: 'invalid', debug: 'invalid expression' }
      : { status: 'valid', debug: `valid ${kind}`, latex: expression },
}));

// @ac "AC-001" Single Response delivery uses the shared validation/help pattern.
// @ac "AC-020" Student Single Response shows parser-derived preview for valid input.
// @ac "AC-028" Delivery keeps validation, help, preview, and continued typing behavior.
// @ac "AC-030" Student-facing invalid feedback avoids parser offsets and internal details.
describe('multiple choice delivery', () => {
  let restoreMathJax: any;

  beforeEach(() => {
    restoreMathJax = window.MathJax;
    window.MathJax = {
      startup: { promise: Promise.resolve() },
      typesetPromise: jest.fn().mockResolvedValue(undefined),
    };
  });

  afterEach(() => {
    window.MathJax = restoreMathJax;
  });

  const renderShortAnswer = (
    model: ShortAnswerModelSchema,
    contextOverrides: Partial<ActivityContext> = {},
  ) => {
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
        ...contextOverrides,
      },
      preview: false,
    };
    const store = configureStore({}, activityDeliverySlice.reducer);

    return render(
      <Provider store={store}>
        <DeliveryElementProvider {...defaultDeliveryElementProps} {...props}>
          <ShortAnswerComponent />
        </DeliveryElementProvider>
      </Provider>,
    );
  };

  it('renders ungraded activities correctly', async () => {
    const model = defaultModel();
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
          <ShortAnswerComponent />
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

    // enter an input, expect it to save
    act(() => {
      fireEvent.change(screen.getByLabelText('answer submission textbox'), {
        target: { value: 'answer' },
      });
    });

    // expect a submit button
    const submitButton = screen.getByLabelText('submit');
    expect(submitButton).toBeTruthy();

    // submit and expect a submission
    act(() => {
      fireEvent.click(submitButton);
    });

    expect(onSubmitActivity).toHaveBeenCalledTimes(1);
    expect(onSubmitActivity).toHaveBeenCalledWith(props.state.attemptGuid, [
      {
        attemptGuid: '1',
        response: { input: 'answer' },
      },
    ]);

    // expect results to be displayed after submission
    expect(await screen.findAllByLabelText('result')).toHaveLength(1);
  });

  it('renders integer math expressions with numeric client validation', async () => {
    const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType('integer', '1'));

    renderShortAnswer(model);

    const input = screen.getByLabelText('answer submission textbox');
    fireEvent.change(input, { target: { value: 'not a number' } });

    await waitFor(() => expect(input).toHaveClass('input-error'));
  });

  it.each(['algebraic', 'number_with_units', 'expression_with_units', 'fraction'] as const)(
    'validates %s math expressions with parser feedback',
    async (questionType) => {
      jest.useFakeTimers();
      const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType(questionType, '1'));

      try {
        renderShortAnswer(model);

        const input = screen.getByLabelText('answer submission textbox');
        fireEvent.change(input, { target: { value: 'not a number' } });
        act(() => {
          jest.advanceTimersByTime(200);
        });

        await waitFor(() => expect(input).toHaveClass('input-error'));

        fireEvent.change(input, {
          target: {
            value:
              questionType === 'fraction'
                ? '1/2'
                : questionType.includes('units')
                ? '3x m/s'
                : '2x + 6',
          },
        });
        act(() => {
          jest.advanceTimersByTime(200);
        });

        await waitFor(() => expect(input).toHaveClass('input-success'));
      } finally {
        jest.useRealTimers();
      }
    },
  );

  it('shows math expression previews only while the valid math input is focused', async () => {
    jest.useFakeTimers();
    const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType('algebraic', '1'));

    try {
      renderShortAnswer(model);

      const input = screen.getByLabelText('answer submission textbox');
      fireEvent.change(input, { target: { value: '2x + 6' } });
      act(() => {
        jest.advanceTimersByTime(200);
      });

      await waitFor(() => expect(input).toHaveClass('input-success'));
      expect(screen.queryByText('Preview')).not.toBeInTheDocument();

      fireEvent.focus(input);
      expect(screen.getByText('Preview')).toBeInTheDocument();

      fireEvent.blur(input);
      expect(screen.queryByText('Preview')).not.toBeInTheDocument();
    } finally {
      jest.useRealTimers();
    }
  });

  it('suppresses math expression previews when the user preference is disabled', async () => {
    jest.useFakeTimers();
    const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType('algebraic', '1'));

    try {
      renderShortAnswer(model, { showMathPreviews: false });

      const input = screen.getByLabelText('answer submission textbox');
      fireEvent.focus(input);
      fireEvent.change(input, { target: { value: '2x + 6' } });
      act(() => {
        jest.advanceTimersByTime(200);
      });

      await waitFor(() => expect(input).toHaveClass('input-success'));
      expect(screen.queryByText('Preview')).not.toBeInTheDocument();
    } finally {
      jest.useRealTimers();
    }
  });

  it('renders LaTeX direct math expressions with the math input', () => {
    const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType('latex_direct', '1'));

    const { container } = renderShortAnswer(model);

    expect(container.querySelector('.math-input')).toBeTruthy();
    expect(screen.queryByLabelText('answer submission textbox')).not.toBeInTheDocument();
  });
});
