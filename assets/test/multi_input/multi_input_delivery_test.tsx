import React from 'react';
import { Provider } from 'react-redux';
import '@testing-library/jest-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { DeliveryElementProvider } from 'components/activities/DeliveryElementProvider';
import { MultiInputComponent } from 'components/activities/multi_input/MultiInputDelivery';
import { MultiInputActions } from 'components/activities/multi_input/actions';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { defaultModel } from 'components/activities/multi_input/utils';
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
}));

describe('multi input delivery', () => {
  const renderMultiInput = (model: MultiInputSchema) => {
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
    const store = configureStore({}, activityDeliverySlice.reducer);

    return render(
      <Provider store={store}>
        <DeliveryElementProvider {...defaultDeliveryElementProps} {...props}>
          <MultiInputComponent />
        </DeliveryElementProvider>
      </Provider>,
    );
  };

  it('renders integer math expressions with numeric client validation', async () => {
    const base = defaultModel();
    const model = dispatch(base, MultiInputActions.setQuestionType(base.inputs[0].id, 'integer'));

    renderMultiInput(model);

    const input = screen.getByLabelText('answer submission textbox');
    fireEvent.change(input, { target: { value: 'not a number' } });

    await waitFor(() => expect(input).toHaveClass('input-error'));
  });

  it.each(['algebraic', 'number_with_units', 'expression_with_units'] as const)(
    'validates %s math expressions with parser feedback',
    async (questionType) => {
      const base = defaultModel();
      const model = dispatch(
        base,
        MultiInputActions.setQuestionType(base.inputs[0].id, questionType),
      );

      renderMultiInput(model);

      const input = screen.getByLabelText('answer submission textbox');
      fireEvent.change(input, { target: { value: 'not a number' } });

      await waitFor(() => expect(input).toHaveClass('input-error'));

      fireEvent.change(input, {
        target: { value: questionType.includes('units') ? '3x m/s' : '2x + 6' },
      });

      await waitFor(() => expect(input).toHaveClass('input-success'));
    },
  );

  it('renders LaTeX direct math expressions with the math input', () => {
    const base = defaultModel();
    const model = dispatch(
      base,
      MultiInputActions.setQuestionType(base.inputs[0].id, 'latex_direct'),
    );

    const { container } = renderMultiInput(model);

    expect(container.querySelector('.math-input')).toBeTruthy();
    expect(screen.queryByLabelText('answer submission textbox')).not.toBeInTheDocument();
  });
});
