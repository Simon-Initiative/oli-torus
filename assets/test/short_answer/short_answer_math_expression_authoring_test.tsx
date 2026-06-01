import React from 'react';
import { act } from 'react-dom/test-utils';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { AuthoringElementProvider } from 'components/activities/AuthoringElementProvider';
import { ShortAnswerActions } from 'components/activities/short_answer/actions';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import {
  defaultModel,
  shortAnswerMathExpressionConfig,
  shortAnswerQuestionType,
} from 'components/activities/short_answer/utils';
import { MatchConfigs } from 'data/activities/model/match';
import { makeMatchConfigResponse } from 'data/activities/model/responses';
import { dispatch } from 'utils/test_utils';
import { defaultAuthoringElementProps } from '../utils/activity_mocks';

jest.mock('gleam/torusExpression', () => ({
  previewMathExpressionSyntax: jest.fn((expression: string, kind: 'expression' | 'quantity') =>
    expression.includes('bad')
      ? { status: 'invalid', debug: 'invalid expression' }
      : {
          status: 'valid',
          debug: `valid ${kind}`,
          latex: kind === 'quantity' ? '9.8\\,m/s^2' : expression,
        },
  ),
}));

// @ac "AC-024" Answer-key expected-answer editors expose validation, help, and preview.
// @ac "AC-025" Targeted feedback editors expose validation, help, and preview.
// @ac "AC-026" Candidate/test expression coverage is satisfied by the shared editor path when present.
// @ac "AC-027" Required author fields keep existing persistence and grading semantics unchanged.
describe('short answer math expression authoring', () => {
  let restoreMathJax: any;

  beforeEach(() => {
    jest.useFakeTimers();
    restoreMathJax = window.MathJax;
    window.MathJax = {
      startup: { promise: Promise.resolve() },
      typesetPromise: jest.fn().mockResolvedValue(undefined),
    };
  });

  afterEach(() => {
    window.MathJax = restoreMathJax;
    jest.useRealTimers();
  });

  it('uses shared math expression help and preview for the answer key editor', () => {
    const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType('algebraic', '1'));
    const response = model.authoring.parts[0].responses[0];
    const onEditResponseMatchConfig = jest.fn();

    render(
      <AuthoringElementProvider {...defaultAuthoringElementProps(model)}>
        <InputEntry
          inputType={model.inputType}
          questionType={shortAnswerQuestionType(model)}
          mathExpressionConfig={shortAnswerMathExpressionConfig(model)}
          response={response}
          onEditResponseRule={jest.fn()}
          onEditResponseMatchConfig={onEditResponseMatchConfig}
        />
      </AuthoringElementProvider>,
    );

    fireEvent.click(screen.getByRole('button', { name: 'Math expression syntax help' }));
    expect(screen.getByRole('link', { name: 'Learn more' })).toHaveAttribute(
      'href',
      '/help/math-syntax',
    );

    fireEvent.change(screen.getByLabelText('Correct answer'), { target: { value: '2x + 6' } });
    act(() => {
      jest.advanceTimersByTime(200);
    });

    expect(screen.getByText('Preview')).toBeInTheDocument();
    expect(screen.getByText('\\[2x + 6\\]')).toBeInTheDocument();
    expect(onEditResponseMatchConfig).toHaveBeenCalledWith(
      response.id,
      expect.objectContaining({
        type: 'math_expression',
        math: expect.objectContaining({ expected: '2x + 6' }),
      }),
    );
  });

  it('uses quantity validation and preview for algebraic-with-units targeted feedback editors', () => {
    const model = dispatch(
      defaultModel(),
      ShortAnswerActions.setQuestionType('expression_with_units', '1'),
    );
    const response = makeMatchConfigResponse(MatchConfigs.unitAware('9.8 m/s^2'), 0);

    render(
      <AuthoringElementProvider {...defaultAuthoringElementProps(model)}>
        <InputEntry
          inputType={model.inputType}
          questionType={shortAnswerQuestionType(model)}
          mathExpressionConfig={shortAnswerMathExpressionConfig(model)}
          response={response}
          onEditResponseRule={jest.fn()}
          onEditResponseMatchConfig={jest.fn()}
          allowUnitMismatchTarget
        />
      </AuthoringElementProvider>,
    );

    expect(screen.getByRole('button', { name: 'Math expression syntax help' })).toBeInTheDocument();
    expect(screen.getByLabelText('Correct answer')).toHaveValue('9.8 m/s^2');

    act(() => {
      jest.advanceTimersByTime(200);
    });

    expect(screen.getByText('Preview')).toBeInTheDocument();
    expect(screen.getByLabelText('Correct answer')).toHaveAttribute('aria-invalid', 'false');
    expect(screen.getByLabelText('Wrong units')).toBeInTheDocument();
  });

  it.each(['number_with_units', 'fraction'] as const)(
    'uses shared math expression help and preview for %s answer editors',
    (questionType) => {
      const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType(questionType, '1'));
      const response =
        questionType === 'fraction'
          ? makeMatchConfigResponse(MatchConfigs.algebraicEquivalence('1/2'), 0)
          : makeMatchConfigResponse(MatchConfigs.unitAware('9.8 m/s^2'), 0);
      const onEditResponseMatchConfig = jest.fn();

      render(
        <AuthoringElementProvider {...defaultAuthoringElementProps(model)}>
          <InputEntry
            inputType={model.inputType}
            questionType={shortAnswerQuestionType(model)}
            mathExpressionConfig={shortAnswerMathExpressionConfig(model)}
            response={response}
            onEditResponseRule={jest.fn()}
            onEditResponseMatchConfig={onEditResponseMatchConfig}
            allowUnitMismatchTarget
          />
        </AuthoringElementProvider>,
      );

      fireEvent.change(screen.getByLabelText('Correct answer'), {
        target: { value: questionType === 'fraction' ? '2/4' : '10 m/s^2' },
      });
      act(() => {
        jest.advanceTimersByTime(200);
      });

      expect(
        screen.getByRole('button', { name: 'Math expression syntax help' }),
      ).toBeInTheDocument();
      expect(screen.getByText('Preview')).toBeInTheDocument();
      expect(onEditResponseMatchConfig).toHaveBeenCalled();
    },
  );
});
