import { containsRule, eqRule, matchRule } from 'data/activities/model/rules';
import {
  makeChoice,
  makeResponse,
  makePart,
  makeUndoable,
  PostUndoable,
  makeHint,
} from 'components/activities/types';
import { clone } from 'utils/common';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { Operations } from 'utils/pathOperations';
import { getPartById, getParts } from 'data/activities/model/utils1';
import { InputRef } from 'data/content/model';
import { Editor, Transforms } from 'slate';

export const MultiInputActions = {
  // editStem(content: RichText, id: string) {
  //   return (model: HasStems, _post: PostUndoable) => {
  //     Operations.apply(model, Operations.replace(`$..stems[?(@.id==${id})].content`, content));
  //   };
  // },

  // removeStem(id: string) {
  //   return (model: HasStems, _post: PostUndoable) => {
  //     Operations.apply(model, Operations.filter('$..stems', `[?(@.id!=${id})]`));
  //   };
  // },

  // editStemAndPreviewText(content: RichText, id: string) {
  //   return (model: HasStems & HasPreviewText, _post: PostUndoable) => {
  //     MultiInputActions.editStem(content, id)(model, _post);
  //     // TODO: Intersperse something like <Dropdown> for the input after the stem
  //     model.authoring.previewText = model.stems
  //       .map((stem) => toSimpleText({ children: stem.content.model }))
  //       .join('');
  //   };
  // },

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
      const result = {
        dropdown: {
          part: makePart(
            [makeResponse(matchRule(choiceA.id), 1, ''), makeResponse(matchRule('.*'), 0, '')],
            [makeHint('')],
          ),
        },
        numeric: {
          part: makePart(
            [makeResponse(eqRule('1'), 1, ''), makeResponse(matchRule('.*'), 0, '')],
            [makeHint('')],
          ),
        },
        text: {
          part: makePart(
            [makeResponse(containsRule('answer'), 1, ''), makeResponse(matchRule('.*'), 0, '')],
            [makeHint('')],
          ),
        },
      }[inputRef.inputType];

      switch (inputRef.inputType) {
        case 'dropdown':
          const choiceA = makeChoice('Choice A');
          const choiceB = makeChoice('Choice B');

          model.choices.push(choiceA, choiceB);
          input = { type: 'dropdown', id, partId: part.id, choiceIds: [choiceA.id, choiceB.id] };
      }
      // Handle choices too
      model.authoring.parts.push(result.part);
    };
  },

  removePart(id: string) {
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

      Operations.applyAll(model, [Operations.filter('$..parts', `[?(@.id!=${id})]`)]);

      // remove choices if dropdown
      if (input.type === 'dropdown') {
        model.choices = model.choices.filter((choice) => !input.choiceIds.includes(choice.id));
      }

      const undoable = makeUndoable('Removed a part', [
        Operations.replace('$.authoring', clone(model.authoring)),
        // Operations.insert('$.choices', clone(choice), index),
      ]);
      post(undoable);
    };
  },
};
