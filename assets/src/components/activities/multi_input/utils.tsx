import React from 'react';
import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { setDifference, setUnion } from 'components/activities/common/utils';
import {
  MultiInput,
  MultiInputSchema,
  MultiInputType,
} from 'components/activities/multi_input/schema';
import {
  ChoiceId,
  MatchStyle,
  Part,
  Response,
  Transform,
  makeChoice,
  makeHint,
  makePart,
  makeResponse,
  makeTransformation,
} from 'components/activities/types';
// import { Responses } from 'data/activities/model/responses';
import {
  containsRule,
  eqRule,
  equalsRule,
  isTextRule,
  matchRule,
} from 'data/activities/model/rules';
import { Model } from 'data/content/model/elements/factories';
import { InputRef, Paragraph } from 'data/content/model/elements/types';
import { elementsOfType } from 'data/content/utils';
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

export const defaultRuleForInputType = (inputType: string | undefined, choiceId?: string) => {
  switch (inputType) {
    case 'numeric':
      return eqRule(0);
    case 'math':
      return equalsRule('');
    case 'dropdown':
      if (choiceId === undefined)
        throw new Error('choiceId paramenter required for dropdown input type');
      return matchRule(choiceId);
    case 'text':
    default:
      return containsRule('');
  }
};

export const constructRule = (
  inputRule: string,
  inputMatchStyle: MatchStyle | undefined,
  inputId: string,
  rule: string,
  append: boolean,
  exclude?: boolean,
): string => {
  const inputRules: Map<string, string> = purseMultiInputRule(inputRule);

  const matchStyle: MatchStyle = inputMatchStyle ? inputMatchStyle : 'all';
  let ruleSeparator = ' && ';
  if (matchStyle === 'any' || matchStyle === 'none') {
    ruleSeparator = ' || ';
  }
  const editedRule: string = replaceWithInputRef(inputId, rule);

  let updatedRule = '';
  let alreadyIncluded = false;
  Array.from(inputRules.keys()).forEach((k) => {
    if (k === inputId) {
      alreadyIncluded = true;
      if (!exclude) {
        updatedRule = updatedRule === '' ? editedRule : updatedRule + ruleSeparator + editedRule;
      }
    } else {
      updatedRule =
        updatedRule === ''
          ? '' + inputRules.get(k)
          : updatedRule + ruleSeparator + inputRules.get(k);
    }
  });

  if (append && !alreadyIncluded) {
    updatedRule = updatedRule === '' ? '' + editedRule : updatedRule + ruleSeparator + editedRule;
  }
  if (matchStyle === 'none' && updatedRule !== '') {
    updatedRule = '!(' + updatedRule + ')';
  }
  return updatedRule;
};

export const MultiInputResponses = {
  catchAll: (inputId: string, text = 'Incorrect') => {
    const catchAllRespose = makeResponse(replaceWithInputRef(inputId, matchRule('.*')), 0, text);
    catchAllRespose.catchAll = true;
    return addRef(inputId, catchAllRespose);
  },
  forTextInput: (inputId: string, correctText = 'Correct', incorrectText = 'Incorrect') => [
    addRef(
      inputId,
      makeResponse(replaceWithInputRef(inputId, containsRule('answer')), 1, correctText),
    ),
    MultiInputResponses.catchAll(inputId, incorrectText),
  ],
  forNumericInput: (inputId: string, correctText = 'Correct', incorrectText = 'Incorrect') => [
    addRef(inputId, makeResponse(replaceWithInputRef(inputId, eqRule(1)), 1, correctText)),
    MultiInputResponses.catchAll(inputId, incorrectText),
  ],
  forMathInput: (inputId: string, correctText = 'Correct', incorrectText = 'Incorrect') => [
    addRef(inputId, makeResponse(replaceWithInputRef(inputId, equalsRule('')), 1, correctText)),
    MultiInputResponses.catchAll(inputId, incorrectText),
  ],
  forMultipleChoice: (
    inputId: string,
    correctChoiceId: ChoiceId,
    correctText = 'Correct',
    incorrectText = 'Incorrect',
  ) => [
    addRef(
      inputId,
      makeResponse(replaceWithInputRef(inputId, matchRule(correctChoiceId)), 1, correctText),
    ),
    addRef(inputId, makeResponse(replaceWithInputRef(inputId, matchRule('.*')), 0, incorrectText)),
  ],
};

export const replaceWithInputRef = (inputId: string, rule: string) => {
  if (rule.includes('input_ref_')) return rule;
  return rule.replace(/input/g, 'input_ref_' + inputId);
};

export const addRef = (inputId: string, response: Response): Response => {
  if (!response.inputRefs) response.inputRefs = [];
  if (!response.inputRefs.includes(inputId)) response.inputRefs.push(inputId);
  return response;
};

export const defaultModel = (): MultiInputSchema => {
  const input = Model.inputRef();
  const partId = '1';

  return {
    stem: multiInputStem(input),
    choices: [],
    inputs: [{ inputType: 'text', id: input.id, partId: partId }],
    submitPerPart: false,
    multInputsPerPart: true,
    authoring: {
      parts: [
        makePart(MultiInputResponses.forTextInput(input.id), [makeHint('')], partId, [input.id]),
      ],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle, true)],
      previewText: 'Example question with a fill in the blank',
    },
  };
};

export const friendlyType = (type: MultiInputType) => {
  if (type === 'dropdown') {
    return 'Dropdown';
  }

  switch (type) {
    case 'numeric':
      return 'Number';

    case 'math':
      return 'Math';

    case 'text':
    default:
      return 'Text';
  }
};

export const partTitle = (input: MultiInput, index: number) => (
  <div>
    {`Part ${index + 1}: `}
    <span className="text-muted">{friendlyType(input.inputType)}</span>
  </div>
);

export const inputTitle = (input: MultiInput, index: number) => (
  <div>
    {`Input ${index + 1}: `}
    <span className="text-muted">{friendlyType(input.inputType)}</span>
  </div>
);

export const purseMultiInputRule = (rule: string): any => {
  const ruleRegex = RegExp('input_ref_.*?}', 'g');

  let reg;
  const entries: Map<string, string> = new Map<string, string>();

  while ((reg = ruleRegex.exec(rule)) !== null) {
    entries.set(reg[0].split('_')[2].split(' ')[0], reg[0]);
  }
  return entries;
};

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
  if (model.multInputsPerPart) return true;
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
  const part = makePart(MultiInputResponses.forTextInput(ref.id), [makeHint('')]);
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
    if (model.multInputsPerPart) return;
    const choices = [makeChoice('Choice A'), makeChoice('Choice B')];
    const part = makePart(
      input.inputType === 'dropdown'
        ? MultiInputResponses.forMultipleChoice(input.id, choices[0].id)
        : input.inputType === 'numeric'
        ? MultiInputResponses.forNumericInput(input.id)
        : MultiInputResponses.forTextInput(input.id),
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
    part.responses =
      type === 'dropdown' ? MultiInputResponses.forTextInput(ref.id) : part.responses;
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
    if (model.multInputsPerPart) return;
    // create new input and part for the input ref in the stem
    const part = makePart(MultiInputResponses.forTextInput(ref.id), [makeHint('')]);
    model.inputs.push({ id: ref.id, inputType: 'text', partId: part.id } as MultiInput);
    model.authoring.parts.push(part);
  });
  return model;
}
