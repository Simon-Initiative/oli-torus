import React, { useState } from 'react';
import { act } from 'react-dom/test-utils';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { AuthoringElementProvider } from 'components/activities/AuthoringElementProvider';
import { ShortAnswerActions } from 'components/activities/short_answer/actions';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { MathExpressionSettings } from 'components/activities/short_answer/sections/MathExpressionSettings';
import {
  defaultModel,
  shortAnswerMathExpressionConfig,
  shortAnswerQuestionType,
} from 'components/activities/short_answer/utils';
import { MatchConfigs, MathExpressionQuestionConfig } from 'data/activities/model/match';
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

// @ac "AC-024" Answer-key expected-answer editors expose validation and help.
// @ac "AC-025" Targeted feedback editors expose validation and help.
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

  it('uses shared math expression help for the answer key editor', () => {
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

    expect(onEditResponseMatchConfig).toHaveBeenCalledWith(
      response.id,
      expect.objectContaining({
        type: 'math_expression',
        math: expect.objectContaining({ expected: '2x + 6' }),
      }),
    );
  });

  it('defaults variable settings to x with a domain and explanatory copy', () => {
    const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType('algebraic', '1'));

    render(
      <AuthoringElementProvider {...defaultAuthoringElementProps(model)}>
        <MathExpressionSettings
          questionType="algebraic"
          config={{ validation: { allowedVariables: [], domains: [] } }}
          onChange={jest.fn()}
        />
      </AuthoringElementProvider>,
    );

    expect(screen.getByRole('button', { name: 'x' })).toHaveAttribute('aria-pressed', 'true');
    expect(screen.getByText(/The evaluator samples each selected variable/)).toBeInTheDocument();
    expect(screen.getByText('Variable x')).toBeInTheDocument();
    expect(screen.getByLabelText('Minimum value for x')).toHaveValue(-10);
    expect(screen.getByLabelText('Maximum value for x')).toHaveValue(10);
    expect(screen.getByLabelText('Include min')).toBeChecked();
    expect(screen.getByLabelText('Include max')).toBeChecked();
    expect(screen.getByLabelText('Integer values only')).not.toBeChecked();
  });

  it('adds variables with default domains and selects their configuration panel', () => {
    const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType('algebraic', '1'));

    const Harness = () => {
      const [config, setConfig] = useState<MathExpressionQuestionConfig>({
        validation: { allowedVariables: ['x'], domains: [] },
      });

      return (
        <AuthoringElementProvider {...defaultAuthoringElementProps(model)}>
          <MathExpressionSettings questionType="algebraic" config={config} onChange={setConfig} />
          <span data-testid="allowed-variables">
            {config.validation?.allowedVariables?.join('|')}
          </span>
          <span data-testid="domain-names">
            {config.validation?.domains?.map(({ name }) => name).join('|')}
          </span>
        </AuthoringElementProvider>
      );
    };

    render(<Harness />);

    fireEvent.change(screen.getByLabelText('New variable'), { target: { value: 'y' } });
    fireEvent.click(screen.getByRole('button', { name: 'Add variable' }));

    expect(screen.getByTestId('allowed-variables')).toHaveTextContent('x|y');
    expect(screen.getByTestId('domain-names')).toHaveTextContent('x|y');
    expect(screen.getByRole('button', { name: 'y' })).toHaveAttribute('aria-pressed', 'true');
    expect(screen.getByText('Variable y')).toBeInTheDocument();
    expect(screen.getByLabelText('Minimum value for y')).toHaveValue(-10);
    expect(screen.getByLabelText('Maximum value for y')).toHaveValue(10);
  });

  it('edits selected variable domains and structured sample value lists', () => {
    const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType('algebraic', '1'));

    const Harness = () => {
      const [config, setConfig] = useState<MathExpressionQuestionConfig>({
        validation: { allowedVariables: ['x'], domains: [] },
      });

      return (
        <AuthoringElementProvider {...defaultAuthoringElementProps(model)}>
          <MathExpressionSettings questionType="algebraic" config={config} onChange={setConfig} />
          <span data-testid="serialized-config">{JSON.stringify(config.validation)}</span>
        </AuthoringElementProvider>
      );
    };

    render(<Harness />);

    fireEvent.change(screen.getByLabelText('Minimum value for x'), { target: { value: '-5' } });
    fireEvent.click(screen.getByLabelText('Integer values only'));
    fireEvent.change(screen.getByLabelText('Excluded value for x'), { target: { value: '0' } });
    fireEvent.click(screen.getByRole('button', { name: 'Add excluded value' }));
    fireEvent.change(screen.getByLabelText('Preferred value for x'), { target: { value: '1' } });
    fireEvent.click(screen.getByRole('button', { name: 'Add preferred value' }));

    expect(screen.getByRole('button', { name: 'Remove excluded values 0' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Remove preferred values 1' })).toBeInTheDocument();
    expect(screen.getByTestId('serialized-config')).toHaveTextContent('"value":-5');
    expect(screen.getByTestId('serialized-config')).toHaveTextContent('"integerOnly":true');
    expect(screen.getByTestId('serialized-config')).toHaveTextContent('"exclusions":[0]');
    expect(screen.getByTestId('serialized-config')).toHaveTextContent('"preferredValues":[1]');
  });

  it('ignores invalid domain number edits instead of saving NaN', () => {
    const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType('algebraic', '1'));

    const Harness = () => {
      const [config, setConfig] = useState<MathExpressionQuestionConfig>({
        validation: { allowedVariables: ['x'], domains: [] },
      });

      return (
        <AuthoringElementProvider {...defaultAuthoringElementProps(model)}>
          <MathExpressionSettings questionType="algebraic" config={config} onChange={setConfig} />
          <span data-testid="serialized-config">{JSON.stringify(config.validation)}</span>
        </AuthoringElementProvider>
      );
    };

    render(<Harness />);

    fireEvent.change(screen.getByLabelText('Minimum value for x'), { target: { value: '-5' } });
    fireEvent.change(screen.getByLabelText('Minimum value for x'), { target: { value: '-' } });

    expect(screen.getByTestId('serialized-config')).not.toHaveTextContent('NaN');
    expect(screen.getByTestId('serialized-config')).toHaveTextContent('"value":-5');
  });

  it('removes variables while keeping x as the minimum default variable', () => {
    const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType('algebraic', '1'));

    const Harness = () => {
      const [config, setConfig] = useState<MathExpressionQuestionConfig>({
        validation: {
          allowedVariables: ['x', 'y'],
          domains: [
            {
              name: 'x',
              lower: { value: -10, inclusive: true },
              upper: { value: 10, inclusive: true },
            },
            {
              name: 'y',
              lower: { value: -10, inclusive: true },
              upper: { value: 10, inclusive: true },
            },
          ],
        },
      });

      return (
        <AuthoringElementProvider {...defaultAuthoringElementProps(model)}>
          <MathExpressionSettings questionType="algebraic" config={config} onChange={setConfig} />
          <span data-testid="allowed-variables">
            {config.validation?.allowedVariables?.join('|')}
          </span>
        </AuthoringElementProvider>
      );
    };

    render(<Harness />);

    fireEvent.click(screen.getByRole('button', { name: 'Remove variable y' }));
    expect(screen.getByTestId('allowed-variables')).toHaveTextContent('x');
    expect(screen.queryByRole('button', { name: 'y' })).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Remove variable x' }));
    expect(screen.getByTestId('allowed-variables')).toHaveTextContent('x');
    expect(screen.getByRole('button', { name: 'x' })).toBeInTheDocument();
  });

  it('uses quantity validation for algebraic-with-units targeted feedback editors', () => {
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

    expect(screen.getByLabelText('Correct answer')).toHaveAttribute('aria-invalid', 'false');
    expect(screen.getByLabelText('Unit feedback match type')).toHaveValue('none');
    expect(screen.getByRole('option', { name: 'Wrong unit' })).toBeInTheDocument();
    expect(screen.getByRole('option', { name: 'Missing unit' })).toBeInTheDocument();
  });

  it('stores wrong-unit and missing-unit targeted feedback match modes', () => {
    const model = dispatch(
      defaultModel(),
      ShortAnswerActions.setQuestionType('number_with_units', '1'),
    );
    const response = makeMatchConfigResponse(MatchConfigs.unitAware('9.8 m/s^2'), 0);
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

    fireEvent.change(screen.getByLabelText('Unit feedback match type'), {
      target: { value: 'missing_unit' },
    });

    expect(onEditResponseMatchConfig).toHaveBeenLastCalledWith(
      response.id,
      expect.objectContaining({
        type: 'math_expression',
        math: expect.objectContaining({
          mode: 'unit_aware',
          matchMissingUnit: true,
        }),
      }),
    );

    fireEvent.change(screen.getByLabelText('Unit feedback match type'), {
      target: { value: 'wrong_units' },
    });

    expect(onEditResponseMatchConfig).toHaveBeenLastCalledWith(
      response.id,
      expect.objectContaining({
        type: 'math_expression',
        math: expect.objectContaining({
          mode: 'unit_aware',
          matchWrongUnits: true,
        }),
      }),
    );
  });

  it('uses shared math expression help for fraction answer editors', () => {
    const model = dispatch(defaultModel(), ShortAnswerActions.setQuestionType('fraction', '1'));
    const response = makeMatchConfigResponse(MatchConfigs.algebraicEquivalence('1/2'), 0);
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
      target: { value: '2/4' },
    });
    act(() => {
      jest.advanceTimersByTime(200);
    });

    expect(screen.getByRole('button', { name: 'Math expression syntax help' })).toBeInTheDocument();
    expect(onEditResponseMatchConfig).toHaveBeenCalled();
  });

  it('uses numeric answer controls for number_with_units answer editors', () => {
    const model = dispatch(
      defaultModel(),
      ShortAnswerActions.setQuestionType('number_with_units', '1'),
    );
    const response = makeMatchConfigResponse(MatchConfigs.unitAware('9.8 m/s^2'), 0);
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

    expect(
      screen.queryByRole('button', { name: 'Math expression syntax help' }),
    ).not.toBeInTheDocument();
    expect(screen.getByLabelText('Unit feedback match type')).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('Correct answer'), {
      target: { value: '10' },
    });

    expect(onEditResponseMatchConfig).toHaveBeenCalledWith(
      response.id,
      expect.objectContaining({
        type: 'math_expression',
        math: expect.objectContaining({
          mode: 'unit_aware',
          expected: '10',
          operator: 'equal',
        }),
      }),
    );
  });
});
