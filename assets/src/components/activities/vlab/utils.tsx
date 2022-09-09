import { DEFAULT_PART_ID, setDifference, setUnion } from 'components/activities/common/utils';
import {
  VlabInput,
  VlabSchema,
  VlabInputType,
  VlabParameter,
} from 'components/activities/vlab/schema';
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

export const vlabStem = (input: InputRef) => ({
  id: guid(),
  content: [
    {
      type: 'p',
      id: guid(),
      children: [{ text: 'Example question with a fill in the blank ' }, input, { text: '.' }],
    } as Paragraph,
  ],
});

export const defaultModel = (): VlabSchema => {
  const input = Model.inputRef();

  return {
    stem: vlabStem(input),
    choices: [],
    inputs: [{ inputType: 'numeric', id: input.id, partId: DEFAULT_PART_ID }],
    assignmentSource: 'builtIn',
    assignmentPath: 'default',
    assignment: DEFAULT_ASSIGNMENT,
    configuration: DEFAULT_CONFIGURATION,
    reactions: DEFAULT_REACTIONS,
    solutions: DEFAULT_SOLUTIONS,
    species: DEFAULT_SPECIES,
    spectra: DEFAULT_SPECTRA,
    authoring: {
      parts: [makePart(Responses.forNumericInput(), [makeHint('')], DEFAULT_PART_ID)],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle)],
      previewText: 'Example question with a fill in the blank',
    },
  };
};

export const friendlyType = (type: VlabInputType) => {
  return `${
    type === 'dropdown'
      ? 'Dropdown'
      : type === 'vlabvalue'
      ? 'Vlab Value'
      : type === 'numeric'
      ? 'Input (Number)'
      : type === 'math'
      ? 'Input (Math)'
      : 'Input (Text)'
  }`;
};

export const friendlyVlabParameter = (param: VlabParameter) => {
  return `${
    param === 'temp'
      ? 'temperature (deg K)'
      : param === 'volume'
      ? 'volume (L)'
      : param === 'moles'
      ? 'moles'
      : param === 'mass'
      ? 'mass (g)'
      : param === 'molarity'
      ? 'molarity (moles/L)'
      : param === 'concentration'
      ? 'concentration (g/L)'
      : param === 'pH'
      ? 'pH'
      : ''
  }`;
};

export const partTitle = (input: VlabInput, index: number) => (
  <div>
    {`Part ${index + 1}: `}
    <span className="text-muted">{friendlyType(input.inputType)}</span>
  </div>
);

export function guaranteeMultiInputValidity(model: VlabSchema): VlabSchema {
  // Check whether model is valid first to save unnecessarily cloning the model
  if (isValidModel(model)) {
    return model;
  }

  // Model must be cloned before being passed to these mutable functions.
  return ensureHasInput(
    matchInputsToChoices(matchInputsToParts(matchInputsToInputRefs(clone(model)))),
  );
}

function inputsMatchInputRefs(model: VlabSchema) {
  const inputRefs = elementsOfType(model.stem.content, 'input_ref');
  const union = setUnion(
    inputRefs.map(({ id }) => id),
    model.inputs.map(({ id }) => id),
  );
  return union.length === inputRefs.length && union.length === model.inputs.length;
}

function inputsMatchParts(model: VlabSchema) {
  const parts = model.authoring.parts;
  const union = setUnion(
    model.inputs.map(({ partId }) => partId),
    parts.map(({ id }) => id),
  );
  return union.length === model.inputs.length && union.length === parts.length;
}

function inputsMatchChoices(model: VlabSchema) {
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

function hasAnInput(model: VlabSchema) {
  return model.inputs.length > 0;
}

function isValidModel(model: VlabSchema): boolean {
  return (
    hasAnInput(model) &&
    inputsMatchInputRefs(model) &&
    inputsMatchParts(model) &&
    inputsMatchChoices(model)
  );
}

function ensureHasInput(model: VlabSchema) {
  if (hasAnInput(model)) {
    return model;
  }

  // Make new input ref, add to first paragraph of stem, add new input to model.inputs,
  // add new part.
  const ref = Model.inputRef();
  const part = makePart(Responses.forTextInput(), [makeHint('')]);
  const input: VlabInput = { id: ref.id, inputType: 'text', partId: part.id };

  const firstParagraph = model.stem.content.find((elem) => elem.type === 'p') as
    | Paragraph
    | undefined;
  firstParagraph?.children.push(ref);
  firstParagraph?.children.push({ text: '' });

  model.inputs.push(input);
  model.authoring.parts.push(part);

  console.log('New model:' + model);

  return model;
}

function matchInputsToChoices(model: VlabSchema) {
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

function matchInputsToParts(model: VlabSchema) {
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

  unmatchedInputs.forEach((input: VlabInput) => {
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

function matchInputsToInputRefs(model: VlabSchema) {
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

  unmatchedInputs.forEach((input: VlabInput) => {
    // add inputRef to end of first paragraph in stem
    const firstParagraph = model.stem.content.find((e) => e.type === 'p') as Paragraph | undefined;
    firstParagraph?.children.push({ ...Model.inputRef(), id: input.id });
    firstParagraph?.children.push({ text: '' });
  });

  unmatchedInputRefs.forEach((ref) => {
    // create new input and part for the input ref in the stem
    const part = makePart(Responses.forTextInput(), [makeHint('')]);
    model.inputs.push({ id: ref.id, inputType: 'text', partId: part.id } as VlabInput);
    model.authoring.parts.push(part);
  });
  return model;
}

const DEFAULT_ASSIGNMENT = '{ "assignmentText": "Assignment name" }';
const DEFAULT_CONFIGURATION = `
{
  "title": "Stoichiometric Ratios",
  "solutionViewers": [
    {
      "id": "solutionProperties",
      "displayDefault": true,
      "args": {
        "honorSignificantFigures": false
      }
    },
    {
      "id": "aqueous",
      "displayDefault": true,
      "args": {
        "unitsToggleEnabled": true
      }
    },
    {
      "id": "solid",
      "displayDefault": false,
      "args": {
        "unitsToggleEnabled": true
      }
    },
    {
      "id": "spectrometer",
      "displayDefault": false
    },
    {
      "id": "particleView",
      "displayDefault": true
    },
    {
      "id": "thermometer",
      "displayDefault": true
    },
    {
      "id": "pH",
      "displayDefault": true
    },
    {
      "id": "vesselTrackingControl",
      "displayDefault": false
    }
  ],
  "transfer": ["precise", "significantFigures", "realistic"]
}
`;
const DEFAULT_REACTIONS = `
{
  "REACTIONS": {
    "REACTION": [
      {
        "SPECIES_REF": [
          {
            "id": "0",
            "coefficient": "1"
          },
          {
            "id": "1",
            "coefficient": "-1"
          },
          {
            "id": "2",
            "coefficient": "-1"
          }
        ]
      },
      {
        "SPECIES_REF": [
          {
            "id": "5",
            "coefficient": "1"
          },
          {
            "id": "3",
            "coefficient": "-1"
          },
          {
            "id": "4",
            "coefficient": "-1"
          }
        ]
      }
    ]
  }
}
`;
const DEFAULT_SOLUTIONS = `
{
  "FILESYSTEM": {
    "DIRECTORY": [
     {
        "name": "stockroom",
        "SOLUTION": [
          {
            "name": "Distilled H<sub>2</sub>O",
            "description": "Distilled Water",
            "volume": "3.0",
            "vessel": "3LCarboy",
            "species": [
               {
                  "id": "0"
               }
            ]
          },
          {
            "name": "0.154 M NaCl",
            "description": "Sodium Chloride",
            "volume": "0.2",
            "species": [
               {
                  "id": "0"
               },
               {
                  "id": "3",
                  "amount": "0.0308"
               },
               {
                  "id": "4",
                  "amount": "0.0308"
               }
            ]
          }
        ]
      }
    ]
  }
}
`;
const DEFAULT_SPECIES = `
{
 "SPECIES_LIST": {
  "SPECIES": [
      {
        "id": "0",
        "name": "H<sub>2</sub>O",
        "enthalpy": "-285.83",
        "entropy": "69.91",
        "state": "l",
        "molecularWeight": "18.016"
      },
      {
        "id": "1",
        "name": "H<sup>+</sup>",
        "enthalpy": "0.0",
        "entropy": "0.0",
        "molecularWeight": "1.008"
      },
      {
        "id": "2",
        "name": "OH<sup>-</sup>",
        "enthalpy": "-229.99",
        "entropy": "-10.75",
        "molecularWeight": "17.008"
      },
      {
        "id": "3",
        "name": "Na<sup>+</sup>",
        "enthalpy": "-240.12",
        "entropy": "59.0",
        "molecularWeight": "22.99"
      },
      {
        "id": "4",
        "name": "Cl<sup>-</sup>",
        "enthalpy": "-167.58999999999997",
        "entropy": "56.5",
        "molecularWeight": "35.45"
      },
      {
        "id": "5",
        "name": "NaCl",
        "enthalpy": "-411.2",
        "entropy": "72.1",
        "state": "s",
        "molecularWeight": "58.44",
        "density": "2.16"
     }
    ]
  }
}
`;
const DEFAULT_SPECTRA = '{ "SPECTRA_LIST": { "SPECIES": [] } }';
