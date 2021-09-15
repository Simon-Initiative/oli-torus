import '@testing-library/jest-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { AuthoringElementProvider } from 'components/activities/AuthoringElement';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { MultiInputActions } from 'components/activities/multi_input/actions';
import { MultiInputComponent } from 'components/activities/multi_input/MultiInputAuthoring';
import {
  Dropdown,
  FillInTheBlank,
  MultiInputSchema,
} from 'components/activities/multi_input/schema';
import { addTargetedFeedbackFillInTheBlank } from 'components/activities/multi_input/sections/AnswerKeyTab';
import { defaultModel, multiInputStem } from 'components/activities/multi_input/utils';
import {
  makeChoice,
  makeHint,
  makePart,
  makeTransformation,
  Transform,
} from 'components/activities/types';
import { Responses } from 'data/activities/model/responses';
import { inputRef } from 'data/content/model';
import React from 'react';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { Operations } from 'utils/pathOperations';
import { dispatch } from 'utils/test_utils';
import { defaultAuthoringElementProps } from '../utils/activity_mocks';

describe('multi input question - default (with text input)', () => {
  const props = defaultAuthoringElementProps<MultiInputSchema>(defaultModel());
  const { model } = props;
  const store = configureStore();

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

    fireEvent.click(screen.getByText('Answer Key'));
    await screen.findByText('Add targeted feedback');
    fireEvent.click(screen.getByText('Add targeted feedback'));
    const responses = model.authoring.parts[0].responses;
    expect(responses).toHaveLength(3);
    expect(responses[1]).toHaveProperty('rule', 'input contains {another answer}');
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

  it('can remove a text input ref', () => {
    render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <MultiInputComponent />
        </AuthoringElementProvider>
      </Provider>,
    );
    fireEvent.click(screen.getByText('Add Input'));
  });
  // preview text?
  // input ref removed from stem
  // input removed
  // part removed

  test.todo('should reorder parts and inputs when an input ref is removed');
  test.todo('cannot remove an input ref if there is only one');

  test.todo('can switch from text to numeric');
  // targeted responses removed
  // responses set to default numeric
});

describe('multi input question (with numeric input)', () => {
  const input = inputRef();

  const model: MultiInputSchema = {
    stem: multiInputStem(input),
    choices: [],
    inputs: [{ inputType: 'numeric', id: input.id, partId: DEFAULT_PART_ID }],
    authoring: {
      parts: [makePart(Responses.forNumericInput(), [makeHint('')], DEFAULT_PART_ID)],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle)],
      previewText: 'Example question with a fill in the blank',
    },
  };

  test.todo('can add targeted feedback to a numeric input');
  test.todo('can switch from numeric to text');
  test.todo('can switch from numeric to dropdown');
  test.todo('can remove a numeric input ref');
});

describe('multi input question (with dropdown)', () => {
  const input = inputRef();
  const choices = [makeChoice('Choice A'), makeChoice('Choice B')];

  const model: MultiInputSchema = {
    stem: multiInputStem(input),
    choices,
    inputs: [
      {
        inputType: 'dropdown',
        id: input.id,
        partId: DEFAULT_PART_ID,
        choiceIds: choices.map((c) => c.id),
      },
    ],
    authoring: {
      parts: [
        makePart(Responses.forMultipleChoice(choices[0].id), [makeHint('')], DEFAULT_PART_ID),
      ],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle)],
      previewText: 'Example question with a fill in the blank',
    },
  };

  test.todo('can add targeted feedback to a dropdown input');
  test.todo('can reorder choices for a dropdown');
  test.todo('can remove a choice from a dropdown');
  test.todo('can switch from dropdown to numeric');
  test.todo('can switch from dropdown to text');
  // responses set to default text
  // choices matching dropdown removed
  // targeted responses matching dropdown removed

  test.todo('can remove a dropdown input ref');
  // choices matching the dropdown removed
  // targeted responses matching the dropdown removed
});

describe('multi input question', () => {
  test.todo('can add a choice to a dropdown input');

  test.todo('cannot add a choice to a non-dropdown input');
  // const input = model.inputs[0];
  // const updated = dispatch(model, MultiInputActions.addChoice(input.id, makeChoice('')));
  // expect(updated).toEqual(model);

  test.todo('can undo removing an input ref');
  test.todo('can undo removing targeted feedback');
  test.todo('can undo removing a choice');

  test.todo('will reconcile extra parts');
  test.todo('will reconcile missing parts');
});
