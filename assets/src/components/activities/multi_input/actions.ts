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
import { Dropdown, MultiInputSchema } from 'components/activities/multi_input/schema';
import { Operations } from 'utils/pathOperations';
import { getPartById, getParts } from 'data/activities/model/utils1';
import { ID, InputRef } from 'data/content/model';
import { Editor, Operation, Transforms } from 'slate';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { elementsOfType } from 'components/editing/utils';
import { Editor as SlateEditor } from 'slate';
import { ReactEditor } from 'slate-react';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { current } from '@reduxjs/toolkit';

export const MultiInputActions = {
  editStemAndPreviewText(
    content: RichText,
    editor: SlateEditor & ReactEditor,
    operations: Operation[],
  ) {
    return (model: any, post: any) => {
      StemActions.editStemAndPreviewText(content)(model);

      const addedInputRefs = operations
        .filter(
          (operation) => operation.type === 'insert_node' && operation.node.type === 'input_ref',
        )
        .map((operation) => operation.node as InputRef);
      const removedInputRefs = operations
        .filter(
          (operation) => operation.type === 'remove_node' && operation.node.type === 'input_ref',
        )
        .map((operation) => operation.node as InputRef);

      if (addedInputRefs.length) {
        console.log('added input ref', addedInputRefs);
        addedInputRefs.forEach((inputRef) => MultiInputActions.addPart(inputRef)(model, post));
      }
      if (removedInputRefs.length) {
        console.log('removed input ref', removedInputRefs);
        removedInputRefs.forEach((inputRef) =>
          MultiInputActions.removePart(inputRef.partId, inputRef)(model, post),
        );
      }

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
  updateStemWithInput(input: InputRef, editor: Editor) {
    return (_model: any, _post: any) => {
      Transforms.insertNodes(editor, input);
    };
  },

  addDropdown() {
    return (_model: MultiInputSchema, _post: PostUndoable) => {};
  },

  addPart(inputRef: InputRef) {
    return (model: MultiInputSchema, _post: PostUndoable) => {
      const part = (responses: Response[]) => makePart(responses, [makeHint('')], inputRef.partId);

      if (inputRef.inputType === 'dropdown') {
        const choices = inputRef.choiceIds.map((id, i) => makeChoice('Choice ' + (i + 1), id));
        model.choices.push(...choices);
        model.authoring.parts.push(
          part([
            makeResponse(matchRule(choices[0].id), 1, ''),
            makeResponse(matchRule('.*'), 0, ''),
          ]),
        );
        return;
      }

      if (inputRef.inputType === 'numeric') {
        model.authoring.parts.push(
          part([makeResponse(eqRule('1'), 1, ''), makeResponse(matchRule('.*'), 0, '')]),
        );
        return;
      }

      if (inputRef.inputType === 'text') {
        model.authoring.parts.push(
          part([makeResponse(containsRule('answer'), 1, ''), makeResponse(matchRule('.*'), 0, '')]),
        );
        return;
      }
    };
  },

  removePart(id: string, inputRef: InputRef) {
    // IMPORTANT: Make sure removing an input with backspace also removes the matching part (and choices)
    // If this can't be done, add an 'x' button to remove the input that triggers
    // this logic

    return (model: MultiInputSchema, post: PostUndoable) => {
      if (getParts(model).length < 2) {
        return;
      }
      // remove part, input, and join stems at the right indices
      // stem is the one after the part index

      // TODO: Standardize language (input, part, fill in the blank, etc)
      const part = getPartById(model, id);
      const partIndex = getParts(model).findIndex((p) => p.id === id);

      // clone inputs, authoring (or just entire model? ... or will this undo actions after the undo)

      console.log('parts before removing', getParts(current(model)));
      console.log('removing part', current(part));

      Operations.applyAll(model, [Operations.filter('$..parts', `[?(@.id!=${id})]`)]);
      // const allChoiceIds: ChoiceId[] = Object.values(inputRefs)
      //   .filter((input: InputRef) => input.inputType === 'dropdown')
      //   .reduce((acc: ChoiceId[], dropdown: Dropdown) => acc.concat(dropdown.choiceIds), []);
      // console.log(
      //   'new choices',
      //   model.choices.filter((choice) => allChoiceIds.includes(choice.id)),
      // );
      console.log('parts after removing', getParts(current(model)));
      if (inputRef.inputType === 'dropdown') {
        ChoiceActions.setAllChoices(
          model.choices.filter((choice) => !inputRef.choiceIds.includes(choice.id)),
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
