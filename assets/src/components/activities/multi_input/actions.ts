import { Descendant, Editor, Element, Operation } from 'slate';
import { MCActions } from 'components/activities/common/authoring/actions/multipleChoiceActions';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import {
  Dropdown,
  MultiInput,
  MultiInputSchema,
  MultiInputSize,
  MultiInputType,
} from 'components/activities/multi_input/schema';
import {
  Choice,
  ChoiceId,
  Part,
  PostUndoable,
  Stem,
  Transform,
  makeChoice,
  makeHint,
  makePart,
  makeTransformation,
  makeUndoable,
} from 'components/activities/types';
import { elementsAdded, elementsOfType, elementsRemoved } from 'components/editing/slateUtils';
import { Choices } from 'data/activities/model/choices';
import { List } from 'data/activities/model/list';
import { Responses, getCorrectResponse } from 'data/activities/model/responses';
import { matchRule } from 'data/activities/model/rules';
import { getByUnsafe, getPartById, getParts } from 'data/activities/model/utils';
import { InputRef } from 'data/content/model/elements/types';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';

export const MultiInputActions = {
  editStemAndPreviewText(content: Descendant[], editor: Editor, operations: Operation[]) {
    return (model: MultiInputSchema, post: PostUndoable) => {
      const removedInputRefs = elementsRemoved<InputRef>(operations, 'input_ref');

      // Handle error condition - removing an extra input ref that is not present in the model
      if (
        removedInputRefs.length > 0 &&
        removedInputRefs.every((ref) => !model.inputs.find((input) => input.id === ref.id))
      ) {
        StemActions.editStemAndPreviewText(content)(model);
        return;
      }

      if (getParts(model).length - removedInputRefs.length < 1) {
        return;
      }
      if (
        operations.find(
          (op) =>
            op.type === 'insert_node' &&
            Element.isElement(op.node) &&
            op.node.type === 'input_ref' &&
            model.inputs.find((input) => input.id === (op.node as InputRef).id),
        )
      ) {
        // duplicate input id, do nothing
        return;
      }

      MultiInputActions.addMissingParts(operations)(model);
      MultiInputActions.removeExtraParts(operations)(model, post);
      StemActions.editStemAndPreviewText(content)(model);

      // Reorder parts and inputs by new editor model
      const inputRefIds = elementsOfType<InputRef>(editor, 'input_ref').map(({ id }) => id);
      MultiInputActions.reorderInputs(inputRefIds)(model);
      MultiInputActions.reorderPartsByInputs()(model);
    };
  },

  addMissingParts(operations: Operation[]) {
    return (model: MultiInputSchema) => {
      elementsAdded<InputRef>(operations, 'input_ref').forEach((inputRef) =>
        MultiInputActions.addPart(inputRef.id)(model),
      );
    };
  },

  removeExtraParts(operations: Operation[]) {
    return (model: MultiInputSchema, post: PostUndoable) => {
      const removedInputRefs = elementsRemoved<InputRef>(operations, 'input_ref');
      const clonedStem = clone(model.stem);
      const clonedPreviewText = clone(model.authoring.previewText);
      removedInputRefs.forEach((inputRef) =>
        MultiInputActions.removePart(inputRef.id, clonedStem, clonedPreviewText)(model, post),
      );
    };
  },

  addChoice(inputId: string, choice: Choice) {
    return (model: MultiInputSchema) => {
      const input = model.inputs.find((input) => input.id === inputId);
      if (!input || input.inputType !== 'dropdown') return;
      Choices.addOne(choice)(model);
      input.choiceIds.push(choice.id);
    };
  },

  reorderChoices(inputId: string, dropdownChoices: Choice[]) {
    return (model: MultiInputSchema) => {
      const input = model.inputs.find((input) => input.id === inputId);
      if (!input || input.inputType !== 'dropdown') return;

      model.choices = model.choices.filter(
        (choice) => !dropdownChoices.map(({ id }) => id).includes(choice.id),
      );
      model.choices.push(...dropdownChoices);
    };
  },

  reorderPartsByInputs() {
    return (model: MultiInputSchema) => {
      const { getOne, setAll } = List<Part>('$..parts');
      const orderedPartIds = model.inputs.map((input) => input.partId);
      // safety filter in case somehow there's a missing input
      setAll(orderedPartIds.map((id) => getOne(model, id)).filter((x) => !!x))(model);
    };
  },

  reorderInputs(reorderedIds: string[]) {
    return (model: MultiInputSchema) => {
      const { getOne, setAll } = List<MultiInput>('$.inputs');
      // safety filter in case somehow there's a missing input
      setAll(reorderedIds.map((id) => getOne(model, id)).filter((x) => !!x))(model);
    };
  },

  removeChoice(inputId: string, choiceId: ChoiceId) {
    return (model: MultiInputSchema, post: PostUndoable) => {
      const input = getByUnsafe(model.inputs, (input) => input.id === inputId) as Dropdown;
      const inputIndex = input.choiceIds.findIndex((id) => id === choiceId);
      if (input.choiceIds.length < 2) return;

      const choice = Choices.getOne(model, choiceId);
      const choiceIndex = Choices.getAll(model).findIndex((c) => c.id === choiceId);

      // Remove the choice id from the input and the choice from the model
      Choices.removeOne(choiceId)(model);
      input.choiceIds = input.choiceIds.filter((id) => id !== choiceId);

      // if the choice being removed is the correct choice, a new correct choice
      // must be set
      const authoringClone = clone(model.authoring);
      if (getCorrectResponse(model, input.partId).rule === matchRule(choiceId)) {
        MCActions.toggleChoiceCorrectness(input.choiceIds[0], input.partId)(model, post);
      }

      post(
        makeUndoable('Removed a choice', [
          Operations.replace('$.authoring', authoringClone),
          Operations.insert(`$.inputs[?(@.id=='${input.id}')].choiceIds`, choiceId, inputIndex),
          Operations.insert(Choices.path, clone(choice), choiceIndex),
        ]),
      );
    };
  },

  setInputType(id: string, type: MultiInputType) {
    return (model: MultiInputSchema) => {
      const input = getByUnsafe(model.inputs, (x) => x.id === id);

      const inputTypeChanged = input.inputType !== type;
      if (!inputTypeChanged) return;

      const choices = [makeChoice('Choice A'), makeChoice('Choice B')];
      const part = getPartById(model, input.partId);

      if (input.inputType === 'dropdown') {
        MultiInputActions.removeTargetedMappingsForPart(part)(model);
        MultiInputActions.removeChoicesForInput(input)(model);
        MultiInputActions.removeShuffleTransformationForInput(input)(model);
      }

      if (type === 'dropdown') {
        model.choices.push(...choices);
        (input as Dropdown).choiceIds = choices.map(({ id }) => id);

        // shuffle the choices by default
        model.authoring.transformations.push(
          makeTransformation('choices', Transform.shuffle, true, input.partId),
        );
      }

      part.responses = {
        dropdown: Responses.forMultipleChoice(choices[0].id),
        text: Responses.forTextInput(),
        numeric: Responses.forNumericInput(),
        math: Responses.forMathInput(),
      }[type];

      input.inputType = type;
    };
  },

  setInputSize(inputId: string, size: MultiInputSize) {
    return (model: MultiInputSchema) => {
      const input = getByUnsafe(model.inputs, (x) => x.id === inputId);
      if (!input) return;

      const inputSizeChanged = input.size !== size;
      if (!inputSizeChanged) return;

      input.size = size;
    };
  },

  addPart(inputId: string) {
    return (model: MultiInputSchema) => {
      const part = makePart(Responses.forTextInput(), [makeHint('')]);
      model.inputs.push({ inputType: 'text', partId: part.id, id: inputId });
      model.authoring.parts.push(part);
    };
  },

  removeTargetedMappingsForPart(part: Part) {
    return (model: MultiInputSchema) => {
      model.authoring.targeted = model.authoring.targeted.filter(
        ([, responseId]) => !part.responses.find(({ id }) => id === responseId),
      );
    };
  },

  removeChoicesForInput(dropdown: Dropdown) {
    return (model: MultiInputSchema) => {
      model.choices = model.choices.filter((c) => !dropdown.choiceIds.includes(c.id));
    };
  },

  removeShuffleTransformationForInput(dropdown: Dropdown) {
    return (model: MultiInputSchema) => {
      model.authoring.transformations = model.authoring.transformations.filter(
        (t) => t.partId !== dropdown.partId,
      );
    };
  },

  removePart(inputId: string, stem: Stem, previewText: string) {
    return (model: MultiInputSchema, post: PostUndoable) => {
      if (getParts(model).length < 2) {
        return;
      }

      const undoables = makeUndoable('Removed a part', [
        Operations.replace('$.stem', stem),
        Operations.replace('$..previewText', previewText),
        Operations.replace('$.inputs', clone(model.inputs)),
        Operations.replace('$.choices', clone(model.choices)),
        Operations.replace('$.authoring', clone(model.authoring)),
      ]);

      const input = getByUnsafe(model.inputs, (input) => input.id === inputId);
      const part = getPartById(model, input.partId);

      if (input.inputType === 'dropdown') {
        MultiInputActions.removeTargetedMappingsForPart(part)(model);
        MultiInputActions.removeChoicesForInput(input)(model);
      }

      Operations.applyAll(model, [
        Operations.filter('$..parts', `[?(@.id!='${part.id}')]`),
        Operations.filter('$.inputs', `[?(@.id!='${inputId}')]`),
      ]);

      post(undoables);
    };
  },
};
