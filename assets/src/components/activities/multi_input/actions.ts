import { containsRule, eqRule, matchRule } from 'data/activities/model/rules';
import {
  makeChoice,
  makeResponse,
  makePart,
  makeUndoable,
  PostUndoable,
  makeHint,
  Response,
  RichText,
  Part,
  ChoiceId,
} from 'components/activities/types';
import { clone } from 'utils/common';
import { Dropdown, MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { Operations } from 'utils/pathOperations';
import { getByUnsafe, getPartById, getParts } from 'data/activities/model/utils1';
import { ID, InputRef } from 'data/content/model';
import { Editor, Operation, Transforms } from 'slate';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { elementsOfType } from 'components/editing/utils';
import { Editor as SlateEditor } from 'slate';
import { ReactEditor } from 'slate-react';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { current } from '@reduxjs/toolkit';
import { ShortAnswerActions } from 'components/activities/short_answer/actions';

export const MultiInputActions = {
  editStemAndPreviewText(
    content: RichText,
    editor: SlateEditor & ReactEditor,
    operations: Operation[],
  ) {
    return (model: any, post: any) => {
      StemActions.editStemAndPreviewText(content)(model);

      console.log('operations', operations);

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
        MultiInputActions.removePart(inputRef.id)(model, post),
      );

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

  updateInput(id: string, input: Partial<MultiInput>) {
    return (model: MultiInputSchema, _post: any) => {
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

  updateStemWithInput(input: InputRef, editor: Editor) {
    return (_model: any, _post: any) => {
      Transforms.insertNodes(editor, input);
    };
  },

  addDropdown() {
    return (_model: MultiInputSchema, _post: PostUndoable) => {};
  },

  addPart(inputRefId: string) {
    return (model: MultiInputSchema, _post: PostUndoable) => {
      const part = makePart(
        [makeResponse(containsRule('answer'), 1, ''), makeResponse(matchRule('.*'), 0, '')],
        [makeHint('')],
      );
      model.inputs.push({ inputType: 'text', partId: part.id, id: inputRefId });
      model.authoring.parts.push(part);
      // const part = (responses: Response[]) => makePart(responses, [makeHint('')], inputRef.partId);

      // if (inputRef.inputType === 'dropdown') {
      //   const choices = inputRef.choiceIds.map((id, i) => makeChoice('Choice ' + (i + 1), id));
      //   model.choices.push(...choices);
      //   model.authoring.parts.push(
      //     part([
      //       makeResponse(matchRule(choices[0].id), 1, ''),
      //       makeResponse(matchRule('.*'), 0, ''),
      //     ]),
      //   );
      //   return;
      // }

      // if (inputRef.inputType === 'numeric') {
      //   model.authoring.parts.push(
      //     part([makeResponse(eqRule('1'), 1, ''), makeResponse(matchRule('.*'), 0, '')]),
      //   );
      //   return;
      // }

      // if (inputRef.inputType === 'text') {
      //   model.authoring.parts.push(
      //     part([makeResponse(containsRule('answer'), 1, ''), makeResponse(matchRule('.*'), 0, '')]),
      //   );
      //   return;
      // }
    };
  },

  removePart(inputRefId: string) {
    // IMPORTANT: Make sure removing an input with backspace also removes the matching part (and choices)
    // If this can't be done, add an 'x' button to remove the input that triggers
    // this logic

    return (model: MultiInputSchema, post: PostUndoable) => {
      if (getParts(model).length < 2) {
        return;
      }

      const input = getByUnsafe(model.inputs, (input) => input.id === inputRefId);

      // remove part, input, and join stems at the right indices
      // stem is the one after the part index

      // TODO: Standardize language (input, part, fill in the blank, etc)
      const part = getPartById(model, input.partId);
      const partIndex = getParts(model).findIndex((p) => p.id === part.id);

      // clone inputs, authoring (or just entire model? ... or will this undo actions after the undo)

      // console.log('parts before removing', getParts(current(model)));
      // console.log('removing part', current(part));

      Operations.applyAll(model, [
        Operations.filter('$..parts', `[?(@.id!=${part.id})]`),
        Operations.filter('$.inputs', `[?(@.id!=${inputRefId})]`),
      ]);
      // const allChoiceIds: ChoiceId[] = Object.values(inputRefs)
      //   .filter((input: InputRef) => input.inputType === 'dropdown')
      //   .reduce((acc: ChoiceId[], dropdown: Dropdown) => acc.concat(dropdown.choiceIds), []);
      // console.log(
      //   'new choices',
      //   model.choices.filter((choice) => allChoiceIds.includes(choice.id)),
      // );
      // console.log('parts after removing', getParts(current(model)));
      if (input.inputType === 'dropdown') {
        ChoiceActions.setAllChoices(
          model.choices.filter((choice) => !input.choiceIds.includes(choice.id)),
        )(model, post);
      }

      // remove choices if dropdown
      // if (input.type === 'dropdown') {
      //   model.choices = model.choices.filter((choice) => !input.choiceIds.includes(choice.id));
      // }

      const undoable = makeUndoable('Removed a part', [
        Operations.replace('$.authoring', clone(model.authoring)),
        // Operations.insert('$.choices', clone(choice), index),
      ]);
      post(undoable);
    };
  },
};
