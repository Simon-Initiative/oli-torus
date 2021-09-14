import { containsRule, eqRule, matchRule } from 'data/activities/model/rules';
import {
  makeChoice,
  makeResponse,
  makePart,
  makeUndoable,
  PostUndoable,
  makeHint,
  RichText,
  Choice,
  Stem,
  Part,
} from 'components/activities/types';
import { clone } from 'utils/common';
import { Dropdown, MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { Operations, PathOperation } from 'utils/pathOperations';
import { getByUnsafe, getPartById, getParts } from 'data/activities/model/utils1';
import { InputRef } from 'data/content/model';
import { Operation } from 'slate';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { Editor as SlateEditor } from 'slate';
import { ReactEditor } from 'slate-react';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { CHOICES_PATH, getChoice, getChoices } from 'data/activities/model/choiceUtils';
import {
  getCorrectResponse,
  getResponseId,
  getTargetedResponses,
} from 'data/activities/model/responseUtils';
import { MCActions } from 'components/activities/common/authoring/actions/multipleChoiceActions';
import { elementsOfType } from 'components/editing/utils';
import { remove } from 'components/activities/common/utils';

export const MultiInputActions = {
  editStemAndPreviewText(
    content: RichText,
    editor: SlateEditor & ReactEditor,
    operations: Operation[],
  ) {
    return (model: MultiInputSchema, post: any) => {
      const clonedStem = clone(model.stem);
      const clonedPreviewText = clone(model.authoring.previewText);
      StemActions.editStemAndPreviewText(content)(model);

      const addedInputRefs = operations
        .filter(
          (operation) => operation.type === 'insert_node' && operation.node.type === 'input_ref',
        )
        .map((operation) => operation.node as InputRef);
      addedInputRefs.forEach((inputRef) => MultiInputActions.addPart(inputRef.id)(model, post));

      const removedInputRefs = operations
        .filter(
          (operation) => operation.type === 'remove_node' && operation.node.type === 'input_ref',
        )
        .map((operation) => operation.node as InputRef);
      removedInputRefs.forEach((inputRef) =>
        MultiInputActions.removePart(inputRef.id, clonedStem, clonedPreviewText)(model, post),
      );

      // Reorder parts and inputs by new editor model
      const inputRefIds = (elementsOfType(editor, 'input_ref') as InputRef[]).map(
        (inputRef) => inputRef.id,
      );
      model.inputs = inputRefIds
        .map((id) => model.inputs.find((input) => input.id === id))
        .filter((x) => !!x) as MultiInput[];
      model.authoring.parts = model.inputs
        .map((input) => input.partId)
        .map((partId) => model.authoring.parts.find((part) => part.id === partId))
        .filter((x) => !!x) as Part[];

      // if (addedInputRefs.length) {
      //   console.log('added input ref', addedInputRefs);
      // }
      // if (removedInputRefs.length) {
      // console.log('removed input ref', removedInputRefs);
      // }

      // const difference = (minuend: Map<any, any>, subtrahend: Map<any, any>) =>
      //   new Set([...minuend].filter(([k]) => !subtrahend.has(k)).map(([, v]) => v));

      // // Reconciliation logic
      // const inputRefs = (elementsOfType(editor, 'input_ref') as InputRef[]).reduce(
      //   (acc, ref) => acc.set(ref.partId, ref),
      //   new Map<ID, InputRef>(),
      // );
      // const parts = getParts(model).reduce(
      //   (acc, part) => acc.set(part.id, part),
      //   new Map<ID, Part>(),
      // );
      // const extraInputRefs: Set<InputRef> = difference(inputRefs, parts);
      // const extraParts: Set<Part> = difference(parts, inputRefs);
      // if (extraInputRefs.size > 3 || extraParts.size > 3) {
      //   return;
      // }
      // extraInputRefs.forEach((inputRef) => {
      //   console.log('extra refs', extraInputRefs);
      //   MultiInputActions.addPart(inputRef)(model, post);
      // });
      // extraParts.forEach((part) => {
      //   console.log('extra parts', extraParts);
      //   MultiInputActions.removePart(part.id, inputRefs)(model, post);
      // });
    };
  },

  addChoice(inputId: string, choice: Choice) {
    return (model: MultiInputSchema, post: PostUndoable) => {
      const input = model.inputs.find((input) => input.id === inputId);
      if (!input || input.inputType !== 'dropdown') return;
      ChoiceActions.addChoice(choice)(model, post);
      input.choiceIds.push(choice.id);
    };
  },

  reorderChoices(inputId: string, choices: Choice[]) {
    return (model: MultiInputSchema, _post: PostUndoable) => {
      const input = model.inputs.find((input) => input.id === inputId);
      if (!input || input.inputType !== 'dropdown') return;
      model.choices = model.choices.filter(
        (choice) => !choices.map((c) => c.id).includes(choice.id),
      );
      model.choices.push(...choices);
    };
  },

  removeChoice(inputId: string, choiceId: string) {
    return (model: MultiInputSchema, post: PostUndoable) => {
      const input = getByUnsafe(model.inputs, (input) => input.id === inputId) as Dropdown;
      const inputIndex = input.choiceIds.findIndex((id) => id === choiceId);
      if (input.choiceIds.length < 2) return;

      const choice = getChoice(model, choiceId, CHOICES_PATH);
      const choiceIndex = getChoices(model, CHOICES_PATH).findIndex((c) => c.id === choiceId);

      // Remove the choice id from the input and the choice from the model
      ChoiceActions.removeChoice(choiceId, CHOICES_PATH)(model, post);
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
          Operations.insert(`$.inputs[?(@.id==${input.id})].choiceIds`, choiceId, inputIndex),
          Operations.insert(CHOICES_PATH, clone(choice), choiceIndex),
        ]),
      );
    };
  },

  updateInput(id: string, input: Partial<MultiInput>) {
    return (model: MultiInputSchema, _post: PostUndoable) => {
      const modelInput = getByUnsafe(model.inputs, (x) => x.id === id);

      if (input.inputType && modelInput.inputType !== input.inputType) {
        if (input.inputType === 'dropdown') {
          const choices = [makeChoice('Choice A'), makeChoice('Choice B')];
          model.choices.push(...choices);
          input.choiceIds = choices.map((c) => c.id);
          getPartById(model, modelInput.partId).responses = [
            makeResponse(matchRule(choices[0].id), 1, ''),
            makeResponse(matchRule('.*'), 0, ''),
          ];
        }

        if (input.inputType === 'numeric') {
          getPartById(model, modelInput.partId).responses = [
            makeResponse(eqRule('1'), 1, ''),
            makeResponse(matchRule('.*'), 0, ''),
          ];
        }

        if (input.inputType === 'text') {
          getPartById(model, modelInput.partId).responses = [
            makeResponse(containsRule('answer'), 1, ''),
            makeResponse(matchRule('.*'), 0, ''),
          ];
        }

        if (modelInput.inputType === 'dropdown' && input.inputType !== 'dropdown') {
          model.choices = model.choices.filter((c) => !modelInput.choiceIds.includes(c.id));
        }
      }

      Object.assign(modelInput, input);
    };
  },

  addPart(inputId: string) {
    return (model: MultiInputSchema, _post: PostUndoable) => {
      const part = makePart(
        [makeResponse(containsRule('answer'), 1, ''), makeResponse(matchRule('.*'), 0, '')],
        [makeHint('')],
      );
      model.inputs.push({ inputType: 'text', partId: part.id, id: inputId });
      model.authoring.parts.push(part);
    };
  },

  removePart(inputId: string, stem: Stem, previewText: string) {
    // TODO: Standardize language (input, part, fill in the blank, etc)
    // add warnings for malformed multi input questions
    // xxAdd answer key for inputs (need to extend short answer component)
    // Remove targeted feedback when removing part or changing input type
    // Split out responses by part in delivery, maybe also show total score
    // Add reconciliation logic when missing inputs/parts
    // Merge all the activity data utils
    // Finish displaying hints on each delivery component
    // Write tests
    // Fix issue with adding an input and not being able to select others -> requires a stem update to fix it
    // Handle copy/pasting inputs, maybe blacklist / normalize inputRefs

    return (model: MultiInputSchema, post: PostUndoable) => {
      if (getParts(model).length < 2) {
        return;
      }

      const input = getByUnsafe(model.inputs, (input) => input.id === inputId);
      const inputIndex = model.inputs.findIndex((input) => input.id === inputId);

      const part = getPartById(model, input.partId);
      const partIndex = getParts(model).findIndex((p) => p.id === part.id);

      const choiceUndoables: PathOperation[] = [];
      const targetedUndoables: PathOperation[] = [];
      if (input.inputType === 'dropdown') {
        model.choices.forEach((choice, index) => {
          if (input.choiceIds.includes(choice.id)) {
            choiceUndoables.push(Operations.insert(CHOICES_PATH, clone(choice), index));
          }
        });
        post(
          makeUndoable('Removed feedback', [
            Operations.replace('$.authoring', clone(model.authoring)),
          ]),
        );

        // remove targeted feedbacks
        // remove(
        //   model.authoring.targeted.find((assoc) => getResponseId(assoc) === responseId),
        //   model.authoring.targeted,
        // );

        ChoiceActions.setAllChoices(
          model.choices.filter((choice) => !input.choiceIds.includes(choice.id)),
        )(model, post);
      }

      Operations.applyAll(model, [
        Operations.filter('$..parts', `[?(@.id!=${part.id})]`),
        Operations.filter('$.inputs', `[?(@.id!=${inputId})]`),
      ]);

      post(
        makeUndoable('Removed a part', [
          Operations.insert('$..parts', clone(part), partIndex),
          Operations.insert('$.inputs', clone(input), inputIndex),
          Operations.replace('$.stem', stem),
          Operations.replace('$..previewText', previewText),
          ...choiceUndoables,
        ]),
      );
    };
  },
};
