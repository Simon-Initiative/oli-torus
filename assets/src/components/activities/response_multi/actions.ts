import { Descendant, Editor, Element, Operation } from 'slate';
import { MCActions } from 'components/activities/common/authoring/actions/multipleChoiceActions';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import {
  Dropdown,
  MultiInput,
  MultiInputSize,
  MultiInputType,
} from 'components/activities/multi_input/schema';
import {
  Choice,
  ChoiceId,
  HasParts,
  Part,
  PostUndoable,
  Response,
  ResponseId,
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
import { getCorrectResponse, getResponseBy } from 'data/activities/model/responses';
import { containsRule, matchRule } from 'data/activities/model/rules';
import { getByUnsafe, getPartById, getParts } from 'data/activities/model/utils';
import { InputRef } from 'data/content/model/elements/types';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';
import {
  indexResponseMultiRule,
  ruleInputRefs,
  ruleIsCatchAll,
  toInputRule,
  updateRule,
} from './rules';
import { ResponseMultiInputSchema } from './schema';
import { ResponseMultiInputResponses } from './utils';

export const ResponseMultiInputActions = {
  editStemAndPreviewText(content: Descendant[], editor: Editor, operations: Operation[]) {
    return (model: ResponseMultiInputSchema, post: PostUndoable) => {
      const removedInputRefs = elementsRemoved<InputRef>(operations, 'input_ref');

      // Handle error condition - removing an extra input ref that is not present in the model
      if (
        removedInputRefs.length > 0 &&
        removedInputRefs.every((ref) => !model.inputs.find((input) => input.id === ref.id))
      ) {
        StemActions.editStemAndPreviewText(content)(model);
        return;
      }

      if (!model.multInputsPerPart && getParts(model).length - removedInputRefs.length < 1) {
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

      ResponseMultiInputActions.addMissingParts(operations)(model);
      ResponseMultiInputActions.removeExtraParts(operations)(model, post);
      StemActions.editStemAndPreviewText(content)(model);

      // Reorder parts and inputs by new editor model
      const inputRefIds = elementsOfType<InputRef>(editor, 'input_ref').map(({ id }) => id);
      ResponseMultiInputActions.reorderInputs(inputRefIds)(model);
      ResponseMultiInputActions.reorderPartsByInputs()(model);
    };
  },

  addMissingParts(operations: Operation[]) {
    return (model: ResponseMultiInputSchema) => {
      elementsAdded<InputRef>(operations, 'input_ref').forEach((inputRef) =>
        ResponseMultiInputActions.addPart(inputRef.id)(model),
      );
    };
  },

  removeExtraParts(operations: Operation[]) {
    return (model: ResponseMultiInputSchema, post: PostUndoable) => {
      const removedInputRefs = elementsRemoved<InputRef>(operations, 'input_ref');
      const clonedStem = clone(model.stem);
      const clonedPreviewText = clone(model.authoring.previewText);
      removedInputRefs.forEach((inputRef) =>
        ResponseMultiInputActions.removePart(
          inputRef.id,
          clonedStem,
          clonedPreviewText,
        )(model, post),
      );
    };
  },

  moveInputToPart(inputId: string, partId: string) {
    return (model: ResponseMultiInputSchema, post: PostUndoable) => {
      if (getParts(model).length < 2 || !model.multInputsPerPart) {
        return;
      }

      const undoables = makeUndoable('Removed a part', [
        Operations.replace('$.inputs', clone(model.inputs)),
        Operations.replace('$.choices', clone(model.choices)),
        Operations.replace('$.authoring', clone(model.authoring)),
      ]);

      const input = getByUnsafe(model.inputs, (input) => input.id === inputId);
      const partFrom = getPartById(model, input.partId);
      const partTo = getPartById(model, partId);

      // remove input from partFrom targets
      const targets = partFrom.targets?.filter((value) => value !== input.id);
      // if no targets left, remove partFrom
      if (!targets || targets.length < 1) {
        Operations.applyAll(model, [Operations.filter('$..parts', `[?(@.id!='${partFrom.id}')]`)]);
      } else {
        partFrom.targets = targets;
      }

      partTo.targets ? partTo.targets.push(input.id) : (partTo.targets = [input.id]);
      input.partId = partTo.id;

      // Copy input rule for this id  from first response in old part to first
      // response in new, on assumption that first response is correct one
      const fromRules = indexResponseMultiRule(partFrom.responses[0].rule);

      // merge the rules
      const updatedRule: string = updateRule(
        partTo.responses[0].rule,
        partTo.responses[0].matchStyle,
        inputId,
        fromRules.get(input.id),
        'add',
      );
      partTo.responses[0].rule = updatedRule;

      // removing rule can result in empty rule, which should cause response to be removed
      partFrom.responses.forEach((r) => {
        r.rule = updateRule(r.rule, r.matchStyle, inputId, '', 'remove');
      });
      partFrom.responses = partFrom.responses.filter((r) => r.rule !== '');

      // if dest has a catchall response, append wildcard clause for new input
      const response = partTo.responses.find((r) => ruleIsCatchAll(r.rule));
      if (response) {
        response.rule = updateRule(response.rule, 'all', input.id, matchRule('.*'), 'add');
      }

      post(undoables);
    };
  },

  editRule(id: ResponseId, inputId: string, rule: string) {
    return (draftState: HasParts) => {
      getResponseBy(draftState, (r) => r.id === id).rule = toInputRule(inputId, rule);
    };
  },

  editResponseResponseMultiRule(id: ResponseId, inputId: string, rule: string) {
    return (draftState: HasParts) => {
      const response: Response = getResponseBy(draftState, (r) => r.id === id);
      response.rule = rule;
    };
  },

  addChoice(inputId: string, choice: Choice) {
    return (model: ResponseMultiInputSchema) => {
      const input = model.inputs.find((input) => input.id === inputId);
      if (!input || input.inputType !== 'dropdown') return;
      Choices.addOne(choice)(model);
      input.choiceIds.push(choice.id);
    };
  },

  reorderChoices(inputId: string, dropdownChoices: Choice[]) {
    return (model: ResponseMultiInputSchema) => {
      const input = model.inputs.find((input) => input.id === inputId);
      if (!input || input.inputType !== 'dropdown') return;

      model.choices = model.choices.filter(
        (choice) => !dropdownChoices.map(({ id }) => id).includes(choice.id),
      );
      model.choices.push(...dropdownChoices);
    };
  },

  reorderPartsByInputs() {
    return (model: ResponseMultiInputSchema) => {
      const { getOne, setAll } = List<Part>('$..parts');
      const orderedPartIds = model.inputs.map((input) => input.partId);
      // safety filter in case somehow there's a missing input
      let parts: Part[] = orderedPartIds.map((id) => getOne(model, id)).filter((x) => !!x);
      // remove duplicates
      parts = Array.from(new Set(parts));
      setAll(parts)(model);
    };
  },

  reorderInputs(reorderedIds: string[]) {
    return (model: ResponseMultiInputSchema) => {
      const { getOne, setAll } = List<MultiInput>('$.inputs');
      // safety filter in case somehow there's a missing input
      let inputs: MultiInput[] = reorderedIds.map((id) => getOne(model, id)).filter((x) => !!x);
      // remove duplicates
      inputs = Array.from(new Set(inputs));
      setAll(inputs)(model);
    };
  },

  removeChoice(inputId: string, choiceId: ChoiceId) {
    return (model: ResponseMultiInputSchema, post: PostUndoable) => {
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
      if (
        getCorrectResponse(model, input.partId).rule === toInputRule(inputId, matchRule(choiceId))
      ) {
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
    return (model: ResponseMultiInputSchema) => {
      const input = getByUnsafe(model.inputs, (x) => x.id === id);

      const inputTypeChanged = input.inputType !== type;
      if (!inputTypeChanged) return;

      const choices = [makeChoice('Choice A'), makeChoice('Choice B')];
      const part = getPartById(model, input.partId);

      if (input.inputType === 'dropdown') {
        ResponseMultiInputActions.removeTargetedMappingsForPart(part)(model);
        ResponseMultiInputActions.removeChoicesForInput(input)(model);
        ResponseMultiInputActions.removeShuffleTransformationForInput(input)(model);
      }

      if (type === 'dropdown') {
        model.choices.push(...choices);
        (input as Dropdown).choiceIds = choices.map(({ id }) => id);

        // shuffle the choices by default
        model.authoring.transformations.push(
          makeTransformation('choices', Transform.shuffle, true, input.partId),
        );
      }

      const existingResponses: Response[] = part.responses.filter((r) => {
        const f = ruleInputRefs(r.rule).find((i) => i === id);
        return f ? true : false;
      });

      const switchedReponses = {
        dropdown: ResponseMultiInputResponses.forResponseMultipleChoice(input.id, choices[0].id),
        text: ResponseMultiInputResponses.forTextInput(input.id),
        numeric: ResponseMultiInputResponses.forNumericInput(input.id),
        math: ResponseMultiInputResponses.forMathInput(input.id),
      }[type];

      if (existingResponses.length > 0) {
        existingResponses.forEach((r) => {
          if (ruleIsCatchAll(r.rule)) return;
          const updatedRule: string = updateRule(
            r.rule,
            r.matchStyle,
            input.id,
            switchedReponses[0].rule,
            'modify',
          );

          r.rule = updatedRule;
        });
      } else {
        part.responses = switchedReponses;
      }

      input.inputType = type;
    };
  },

  setInputSize(inputId: string, size: MultiInputSize) {
    return (model: ResponseMultiInputSchema) => {
      const input = getByUnsafe(model.inputs, (x) => x.id === inputId);
      if (!input) return;

      const inputSizeChanged = input.size !== size;
      if (!inputSizeChanged) return;

      input.size = size;
    };
  },

  addPart(inputId: string) {
    return (model: ResponseMultiInputSchema) => {
      if (getParts(model).find((p: Part) => p.targets?.find((t: string) => t === inputId))) return;
      const part = makePart(ResponseMultiInputResponses.forTextInput(inputId), [makeHint('')]);
      part.targets?.push(inputId);
      model.inputs.push({ inputType: 'text', partId: part.id, id: inputId });
      model.authoring.parts.push(part);
    };
  },

  removeTargetedMappingsForPart(part: Part) {
    return (model: ResponseMultiInputSchema) => {
      model.authoring.targeted = model.authoring.targeted.filter(
        ([, responseId]) => !part.responses.find(({ id }) => id === responseId),
      );
    };
  },

  removeChoicesForInput(dropdown: Dropdown) {
    return (model: ResponseMultiInputSchema) => {
      model.choices = model.choices.filter((c) => !dropdown.choiceIds.includes(c.id));
    };
  },

  removeShuffleTransformationForInput(dropdown: Dropdown) {
    return (model: ResponseMultiInputSchema) => {
      model.authoring.transformations = model.authoring.transformations.filter(
        (t) => t.partId !== dropdown.partId,
      );
    };
  },

  removePart(inputId: string, stem: Stem, previewText: string) {
    return (model: ResponseMultiInputSchema, post: PostUndoable) => {
      const input = getByUnsafe(model.inputs, (input) => input.id === inputId);
      const part = getPartById(model, input.partId);
      if (getParts(model).length < 2) {
        if (!(part.targets && part.targets.length > 1 && part.targets.includes(inputId))) return;
      }

      const undoables = makeUndoable('Removed a part', [
        Operations.replace('$.stem', stem),
        Operations.replace('$..previewText', previewText),
        Operations.replace('$.inputs', clone(model.inputs)),
        Operations.replace('$.choices', clone(model.choices)),
        Operations.replace('$.authoring', clone(model.authoring)),
      ]);

      if (part.targets) {
        part.targets = part.targets.filter((t) => t !== inputId);
      }

      part.responses.forEach((r) => {
        r.rule = updateRule(r.rule, r.matchStyle, inputId, containsRule(''), 'remove');
      });
      part.responses = part.responses.filter((r) => r.rule !== '');

      if (input.inputType === 'dropdown') {
        ResponseMultiInputActions.removeTargetedMappingsForPart(part)(model);
        ResponseMultiInputActions.removeChoicesForInput(input)(model);
      }

      const targets = part.targets?.filter((v) => v != input.id);
      if (!targets || targets.length < 1) {
        Operations.applyAll(model, [
          Operations.filter('$..parts', `[?(@.id!='${part.id}')]`),
          Operations.filter('$.inputs', `[?(@.id!='${inputId}')]`),
        ]);
      } else {
        Operations.applyAll(model, [Operations.filter('$.inputs', `[?(@.id!='${inputId}')]`)]);
      }

      post(undoables);
    };
  },

  removeInputFromResponse(inputId: string, responseId: string) {
    return (model: ResponseMultiInputSchema, post: PostUndoable) => {
      const input = getByUnsafe(model.inputs, (input) => input.id === inputId);
      const part = getPartById(model, input.partId);
      const response = part.responses.find((r) => r.id === responseId);

      if (!response || ruleInputRefs(response.rule).length < 2) {
        return;
      }

      response.rule = updateRule(
        response.rule,
        response.matchStyle,
        inputId,
        containsRule(''),
        'remove',
      );
    };
  },
};
