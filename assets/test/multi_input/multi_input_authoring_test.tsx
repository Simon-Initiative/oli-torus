import React from 'react';
import { Provider } from 'react-redux';
import '@testing-library/jest-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { AuthoringElementProvider } from 'components/activities/AuthoringElementProvider';
import { MultiInputComponent } from 'components/activities/multi_input/MultiInputAuthoring';
import { MultiInputActions } from 'components/activities/multi_input/actions';
import {
  Dropdown,
  FillInTheBlank,
  MultiInputSchema,
} from 'components/activities/multi_input/schema';
import {
  AnswerKeyTab,
  addTargetedFeedbackFillInTheBlank,
} from 'components/activities/multi_input/sections/AnswerKeyTab';
import {
  defaultModel,
  multiInputMathExpressionConfig,
  multiInputQuestionOptionGroups,
  multiInputQuestionOptions,
  multiInputQuestionType,
  multiInputStem,
} from 'components/activities/multi_input/utils';
import {
  Transform,
  makeChoice,
  makeHint,
  makePart,
  makeTransformation,
} from 'components/activities/types';
import { Responses } from 'data/activities/model/responses';
import { Model } from 'data/content/model/elements/factories';
import { configureStore } from 'state/store';
import { Operations } from 'utils/pathOperations';
import { dispatch } from 'utils/test_utils';
import { defaultAuthoringElementProps } from '../utils/activity_mocks';

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

const DEFAULT_PART_ID = '1';
const input = Model.inputRef();
const choices = [makeChoice('Choice A'), makeChoice('Choice B')];

const _dropdownModel: MultiInputSchema = {
  stem: multiInputStem(input),
  choices,
  submitPerPart: false,
  inputs: [
    {
      inputType: 'dropdown',
      id: input.id,
      partId: DEFAULT_PART_ID,
      choiceIds: choices.map((c) => c.id),
    },
  ],
  authoring: {
    parts: [makePart(Responses.forMultipleChoice(choices[0].id), [makeHint('')], DEFAULT_PART_ID)],
    targeted: [],
    transformations: [makeTransformation('choices', Transform.shuffle, true)],
    previewText: 'Example question with a fill in the blank',
  },
};

const _numericModel: MultiInputSchema = {
  stem: multiInputStem(input),
  choices: [],
  submitPerPart: false,
  inputs: [{ inputType: 'numeric', id: input.id, partId: DEFAULT_PART_ID }],
  authoring: {
    parts: [makePart(Responses.forNumericInput(), [makeHint('')], DEFAULT_PART_ID)],
    targeted: [],
    transformations: [makeTransformation('choices', Transform.shuffle, true)],
    previewText: 'Example question with a fill in the blank',
  },
};

describe('multi input question - default (with text input)', () => {
  const props = defaultAuthoringElementProps<MultiInputSchema>(defaultModel());
  const { model } = props;
  const store = configureStore();
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

  it('has a stem with an input ref', () => {
    expect(model).toHaveProperty('stem');
  });

  it('has an input', () => {
    expect(model.inputs).toHaveLength(1);
    expect(model.inputs[0]).toHaveProperty('inputType', 'text');
    expect(model.inputs[0]).toHaveProperty('partId', '1');
  });

  it('has a part with text input responses', () => {
    expect(model.authoring.parts).toHaveLength(1);
    const part = model.authoring.parts[0];
    expect(part.responses).toHaveLength(2);
    expect(part.responses[0]).toHaveProperty('score', 1);
    expect(part.responses[0].rule).toMatch(/contains/);
    expect(part.responses[1]).toHaveProperty('score', 0);
    expect(part.responses[1]).toHaveProperty('rule', 'input like {.*}');
  });

  it('has no choices', () => {
    expect(model.choices).toHaveLength(0);
  });

  it('has no targeted responses / mappings', () => {
    expect(model.authoring.targeted).toHaveLength(0);
  });

  it('has preview text', () => {
    expect(model.authoring.previewText).toBeTruthy();
  });

  it('has one hint', () => {
    expect(model.authoring.parts[0].hints).toHaveLength(1);
  });

  it('can add targeted feedback to a text input', async () => {
    render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <MultiInputComponent />
        </AuthoringElementProvider>
      </Provider>,
    );

    const answerKeyLink = await screen.findByText('Answer Key');
    fireEvent.click(answerKeyLink);
    const feedbackLink = await screen.findByText('Add targeted feedback');
    fireEvent.click(feedbackLink);
    const responses = model.authoring.parts[0].responses;
    expect(responses).toHaveLength(3);
    expect(responses[1]).toHaveProperty('rule', 'input contains {}');
    expect(responses[1]).toHaveProperty('score', 0);
  });

  it('can switch from text to dropdown', () => {
    // add targeted feedback
    const input = model.inputs[0] as FillInTheBlank;
    const withTargeted = dispatch(model, addTargetedFeedbackFillInTheBlank(input));

    const updated = dispatch(withTargeted, MultiInputActions.setInputType(input.id, 'dropdown'));

    // choices
    expect(updated.choices).toHaveLength(2);
    const updatedInput = updated.inputs[0] as Dropdown;
    expect(updatedInput.inputType).toEqual('dropdown');
    expect(updatedInput.choiceIds).toEqual(updated.choices.map((c) => c.id));

    // responses
    const responses = updated.authoring.parts[0].responses;
    expect(responses).toHaveLength(2);
    expect(responses.map((r) => ({ rule: r.rule, score: r.score }))).toEqual(
      Responses.forMultipleChoice(updated.choices[0].id).map((r) => ({
        rule: r.rule,
        score: r.score,
      })),
    );
  });

  it('can switch to expression with units with shared variable and unit config', () => {
    const freshModel = defaultModel();
    const input = freshModel.inputs[0] as FillInTheBlank;
    let updated = dispatch(
      freshModel,
      MultiInputActions.setQuestionType(input.id, 'expression_with_units'),
    );

    updated = dispatch(
      updated,
      MultiInputActions.setMathExpressionConfig(input.id, 'expression_with_units', {
        validation: {
          allowedVariables: ['x'],
          domains: [
            {
              name: 'x',
              lower: { value: -2, inclusive: true },
              upper: { value: 5, inclusive: false },
            },
          ],
        },
        unitPolicy: { type: 'convertible_units', units: ['m/s', 'km/hr'] },
      }),
    );

    const updatedInput = updated.inputs[0] as FillInTheBlank;
    const correct = updated.authoring.parts[0].responses[0].matchConfig;

    expect(updatedInput.inputType).toBe('math_expression');
    expect(multiInputQuestionType(updatedInput, correct)).toBe('expression_with_units');
    expect(multiInputMathExpressionConfig(updatedInput, correct)).toMatchObject({
      validation: { allowedVariables: ['x'] },
      unitPolicy: { type: 'convertible_units', units: ['m/s', 'km/hr'] },
    });
    expect(correct?.type === 'math_expression' && correct.math).toMatchObject({
      mode: 'unit_aware',
    });
    expect(correct?.type === 'math_expression' && correct.math).not.toHaveProperty('unitPolicy');
    expect(correct?.type === 'math_expression' && correct.math).not.toHaveProperty('validation');
    expect(updated.authoring.parts[0].responses[0].rule).toBe('');
  });

  it('offers the expanded Multi Input question type list', () => {
    expect(multiInputQuestionOptionGroups.map(({ label }) => label)).toEqual([
      'Text',
      'Math/Numeric',
    ]);
    expect(
      multiInputQuestionOptionGroups.map(({ options }) =>
        options.map(({ displayValue }) => displayValue),
      ),
    ).toEqual([
      ['Dropdown', 'Text'],
      [
        'Algebraic expression',
        'Algebraic expression with units',
        'Fraction',
        'LaTeX Math expression',
        'Number',
        'Number with units',
      ],
    ]);
    expect(
      multiInputQuestionOptionGroups
        .flatMap(({ options }) => options)
        .every((option) => option.description && option.example),
    ).toBe(true);
    expect(multiInputQuestionOptions.map((option) => option.value)).toEqual([
      'dropdown',
      'text',
      'algebraic',
      'expression_with_units',
      'fraction',
      'latex_direct',
      'numeric',
      'number_with_units',
    ]);
  });

  it('can add a new text input with the add input button', async () => {
    render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <MultiInputComponent />
        </AuthoringElementProvider>
      </Provider>,
    );

    fireEvent.click(screen.getByText('Add Input'));

    // stem should be updated with new input ref
    await waitFor(() => {
      const inputRefs = Operations.apply(
        model,
        Operations.find('$..children[?(@.type=="input_ref")]'),
      );
      return expect(inputRefs).toHaveLength(2);
    });

    // new part should be added with text input responses
    expect(model.authoring.parts).toHaveLength(2);
    expect(
      model.authoring.parts[1].responses.map((r) => ({ rule: r.rule, score: r.score })),
    ).toEqual(Responses.forTextInput().map((r) => ({ rule: r.rule, score: r.score })));

    // input should be added as text input
    expect(model.inputs).toHaveLength(2);
    expect(model.inputs[1]).toHaveProperty('inputType', 'text');
  });

  it('uses shared math expression help in answer key and targeted feedback editors', () => {
    const freshModel = defaultModel();
    const originalInput = freshModel.inputs[0] as FillInTheBlank;
    let mathModel = dispatch(
      freshModel,
      MultiInputActions.setQuestionType(originalInput.id, 'algebraic'),
    );
    const mathInput = mathModel.inputs[0] as FillInTheBlank;
    mathModel = dispatch(mathModel, addTargetedFeedbackFillInTheBlank(mathInput));
    const authoringModel = JSON.parse(JSON.stringify(mathModel)) as MultiInputSchema;
    const authoringInput = authoringModel.inputs[0] as FillInTheBlank;

    render(
      <Provider store={configureStore()}>
        <AuthoringElementProvider
          {...defaultAuthoringElementProps<MultiInputSchema>(authoringModel)}
        >
          <AnswerKeyTab input={authoringInput} />
        </AuthoringElementProvider>
      </Provider>,
    );

    expect(screen.getAllByRole('button', { name: 'Math expression syntax help' })).toHaveLength(2);

    const answerEditors = screen.getAllByLabelText('Correct answer');
    expect(answerEditors).toHaveLength(2);
  });
});
