import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { DEFAULT_PART_ID, setDifference, setUnion } from 'components/activities/common/utils';
import {
  MultiInput,
  MultiInputSchema,
  MultiInputType,
} from 'components/activities/multi_input/schema';
import {
  makeChoice,
  makeHint,
  makePart,
  makeTransformation,
  Part,
  Transform,
} from 'components/activities/types';
import { Responses } from 'data/activities/model/responses';
import { isTextRule } from 'data/activities/model/rules';
import { Model } from 'data/content/model/elements/factories';
import { InputRef, Paragraph } from 'data/content/model/elements/types';
import { elementsOfType } from 'data/content/utils';
import React from 'react';
import { clone } from 'utils/common';
import guid from 'utils/guid';

export const multiInputOptions: SelectOption<'text' | 'numeric'>[] = [
  { value: 'numeric', displayValue: 'Number' },
  { value: 'text', displayValue: 'Text' },
];

export const multiInputStem = (input: InputRef) => ({
  id: guid(),
  content: [
    {
      type: 'p',
      id: guid(),
      children: [{ text: 'Example question with a fill in the blank ' }, input, { text: '.' }],
    } as Paragraph,
  ],
});

export const defaultModel = (): MultiInputSchema => {
  const input = Model.inputRef();

  return {
    stem: multiInputStem(input),
    choices: [],
    inputs: [{ inputType: 'text', id: input.id, partId: DEFAULT_PART_ID }],
    authoring: {
      parts: [makePart(Responses.forTextInput(), [makeHint('')], DEFAULT_PART_ID)],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle)],
      previewText: 'Example question with a fill in the blank',
    },
  };
};

export const friendlyType = (type: MultiInputType) => {
  if (type === 'dropdown') {
    return 'Dropdown';
  }
  return `Input (${type === 'numeric' ? 'Number' : 'Text'})`;
};

export const partTitle = (input: MultiInput, index: number) => (
  <div>
    {`Part ${index + 1}: `}
    <span className="text-muted">{friendlyType(input.inputType)}</span>
  </div>
);

export function guaranteeMultiInputValidity(model: MultiInputSchema): MultiInputSchema {
  // Check whether model is valid first to save unnecessarily cloning the model
  if (isValidModel(model)) {
    return model;
  }

  // Model must be cloned before being passed to these mutable functions.
  return ensureHasInput(
    matchInputsToChoices(matchInputsToParts(matchInputsToInputRefs(clone(model)))),
  );
}

function inputsMatchInputRefs(model: MultiInputSchema) {
  const inputRefs = elementsOfType(model.stem.content, 'input_ref');
  const union = setUnion(
    inputRefs.map(({ id }) => id),
    model.inputs.map(({ id }) => id),
  );
  return union.length === inputRefs.length && union.length === model.inputs.length;
}

function inputsMatchParts(model: MultiInputSchema) {
  const parts = model.authoring.parts;
  const union = setUnion(
    model.inputs.map(({ partId }) => partId),
    parts.map(({ id }) => id),
  );
  return union.length === model.inputs.length && union.length === parts.length;
}

function inputsMatchChoices(model: MultiInputSchema) {
  const inputChoiceIds = model.inputs.reduce(
    (acc, curr) => (curr.inputType === 'dropdown' ? acc.concat(curr.choiceIds) : acc),
    [] as string[],
  );
  const union = setUnion(
    model.choices.map(({ id }) => id),
    inputChoiceIds,
  );
  return union.length === model.choices.length && union.length === inputChoiceIds.length;
}

function hasAnInput(model: MultiInputSchema) {
  return model.inputs.length > 0;
}

function isValidModel(model: MultiInputSchema): boolean {
  return (
    hasAnInput(model) &&
    inputsMatchInputRefs(model) &&
    inputsMatchParts(model) &&
    inputsMatchChoices(model)
  );
}

function ensureHasInput(model: MultiInputSchema) {
  if (hasAnInput(model)) {
    return model;
  }

  // Make new input ref, add to first paragraph of stem, add new input to model.inputs,
  // add new part.
  const ref = Model.inputRef();
  const part = makePart(Responses.forTextInput(), [makeHint('')]);
  const input: MultiInput = { id: ref.id, inputType: 'text', partId: part.id };

  const firstParagraph = model.stem.content.find((elem) => elem.type === 'p') as
    | Paragraph
    | undefined;
  firstParagraph?.children.push(ref);
  firstParagraph?.children.push({ text: '' });

  model.inputs.push(input);
  model.authoring.parts.push(part);

  return model;
}

function matchInputsToChoices(model: MultiInputSchema) {
  if (inputsMatchChoices(model)) {
    return model;
  }

  const choiceIds = model.choices.map(({ id }) => id);
  const inputChoiceIds = model.inputs.reduce(
    (acc, curr) => (curr.inputType === 'dropdown' ? acc.concat(curr.choiceIds) : acc),
    [] as string[],
  );

  const unmatchedInputChoiceIds = setDifference(inputChoiceIds, choiceIds);

  const unmatchedChoices = setDifference(choiceIds, inputChoiceIds).map((id) =>
    model.choices.find((c) => c.id === id),
  );

  unmatchedInputChoiceIds.forEach((id) => {
    model.choices.push(makeChoice('Choice', id));
  });

  model.choices = model.choices.filter((choice) => !unmatchedChoices.includes(choice));

  return model;
}

function matchInputsToParts(model: MultiInputSchema) {
  if (inputsMatchParts(model)) {
    return model;
  }

  const inputIds = model.inputs.map(({ id }) => id);
  const partIds = model.authoring.parts.map(({ id }) => id);

  const unmatchedInputs = setDifference(inputIds, partIds).map((id) =>
    model.inputs.find((input) => input.id === id),
  );

  const unmatchedParts = setDifference(inputIds, partIds).map((id) =>
    model.authoring.parts.find((part) => part.id === id),
  );

  unmatchedInputs.forEach((input: MultiInput) => {
    const choices = [makeChoice('Choice A'), makeChoice('Choice B')];
    const part = makePart(
      input.inputType === 'dropdown'
        ? Responses.forMultipleChoice(choices[0].id)
        : input.inputType === 'numeric'
        ? Responses.forNumericInput()
        : Responses.forTextInput(),
    );
    model.authoring.parts.push(part);
  });

  unmatchedParts.forEach((part: Part) => {
    const rule = part.responses[0].rule;
    const type = rule.match(/{\d+}/) ? 'dropdown' : isTextRule(rule) ? 'text' : 'numeric';
    const ref = Model.inputRef();
    // If it's a dropdown, change the part to a text input.
    model.inputs.push({
      id: ref.id,
      inputType: type === 'dropdown' ? 'text' : type,
      partId: part.id,
    });
    part.responses = type === 'dropdown' ? Responses.forTextInput() : part.responses;
    // add inputRef to end of first paragraph in stem
    const firstParagraph = model.stem.content.find((elem) => elem.type === 'p') as
      | Paragraph
      | undefined;
    firstParagraph?.children.push(ref);
    firstParagraph?.children.push({ text: '' });
  });

  return model;
}

function matchInputsToInputRefs(model: MultiInputSchema) {
  if (inputsMatchInputRefs(model)) {
    return model;
  }

  const inputRefIds = elementsOfType(model.stem.content, 'input_ref').map(({ id }) => id);
  const inputIds = model.inputs.map(({ id }) => id);

  const unmatchedInputs = setDifference(inputIds, inputRefIds).map((id) =>
    model.inputs.find((input) => input.id === id),
  );

  const unmatchedInputRefs = setDifference(inputRefIds, inputIds).map(
    (id) => ({ id, type: 'input_ref' } as InputRef),
  );

  unmatchedInputs.forEach((input: MultiInput) => {
    // add inputRef to end of first paragraph in stem
    const firstParagraph = model.stem.content.find((e) => e.type === 'p') as Paragraph | undefined;
    firstParagraph?.children.push({ ...Model.inputRef(), id: input.id });
    firstParagraph?.children.push({ text: '' });
  });

  unmatchedInputRefs.forEach((ref) => {
    // create new input and part for the input ref in the stem
    const part = makePart(Responses.forTextInput(), [makeHint('')]);
    model.inputs.push({ id: ref.id, inputType: 'text', partId: part.id } as MultiInput);
    model.authoring.parts.push(part);
  });
  return model;
}
