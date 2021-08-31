import { eqRule, containsRule } from '../../../data/activities/model/rules';
import { matchRule } from 'data/activities/model/rules';
import {
  MultiInputType,
  MultiInput,
  makeMultiDropdownInput,
  makeMultiTextInput,
} from 'components/activities/multi_input/utils';
import {
  RichText,
  HasPreviewText,
  HasStems,
  Part,
  makeChoice,
  makeResponse,
  makePart,
  makeStem,
  makeUndoable,
  PostUndoable,
  makeHint,
} from 'components/activities/types';
import { toSimpleText } from 'data/content/text';
import { assertNever, clone } from 'utils/common';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { current } from '@reduxjs/toolkit';
import { Operations } from 'utils/pathOperations';
import { getPartById, getParts } from 'data/activities/model/utils1';
import { create, p } from 'data/content/model';

export const MultiInputActions = {
  editStem(content: RichText, id: string) {
    return (model: HasStems, _post: PostUndoable) => {
      Operations.apply(model, Operations.replace(`$..stems[?(@.id==${id})].content`, content));
    };
  },

  removeStem(id: string) {
    return (model: HasStems, post: PostUndoable) => {
      Operations.apply(model, Operations.filter('$..stems', `[?(@.id!=${id})]`));
    };
  },

  editStemAndPreviewText(content: RichText, id: string) {
    return (model: HasStems & HasPreviewText, _post: PostUndoable) => {
      MultiInputActions.editStem(content, id)(model, _post);
      // TODO: Intersperse something like <Dropdown> for the input after the stem
      model.authoring.previewText = model.stems
        .map((stem) => toSimpleText({ children: stem.content.model }))
        .join('');
    };
  },

  addPart(type: MultiInputType, index: number) {
    return (model: MultiInputSchema, _post: PostUndoable) => {
      let part: Part;
      let input: MultiInput;
      console.log('index', index);

      switch (type) {
        case 'dropdown':
          const choiceA = makeChoice('Choice A');
          const choiceB = makeChoice('Choice B');

          part = makePart(
            [makeResponse(matchRule(choiceA.id), 1, ''), makeResponse(matchRule('.*'), 0, '')],
            [makeHint('')],
          );
          input = makeMultiDropdownInput([choiceA, choiceB], part.id);
          break;

        case 'numeric':
          part = makePart(
            [makeResponse(eqRule('1'), 1, ''), makeResponse(matchRule('.*'), 0, '')],
            [makeHint('')],
          );
          input = makeMultiTextInput('numeric', part.id);
          break;

        case 'text':
          part = makePart(
            [makeResponse(containsRule('answer'), 1, ''), makeResponse(matchRule('.*'), 0, '')],
            [makeHint('')],
          );
          input = makeMultiTextInput('text', part.id);
          break;

        default:
          assertNever(type);
      }
      model.inputs.splice(index, 0, input);
      model.authoring.parts.splice(index, 0, part);
      model.stems.push(makeStem(''));
    };
  },

  removePart(id: string) {
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

      /*
export type RichText = {
  model: ModelElement[];
  selection: Selection;
};
      */

      // two parts: [p1, p2]
      // three stems: [s1, s2, s3]
      // remove p2 ->
      //    merge s3 into s2
      //    remove s3

      const stem1 = model.stems[partIndex];
      const stem2 = model.stems[partIndex + 1];
      MultiInputActions.editStemAndPreviewText(
        Object.assign(stem1.content, {
          model: stem1.content.model.concat(stem2.content.model),
        }),
        stem1.id,
      )(model, post);
      MultiInputActions.removeStem(stem2.id)(model, post);

      Operations.applyAll(model, [
        Operations.filter('$..parts', `[?(@.id!=${id})]`),
        Operations.filter('$..inputs', `[?(@.partId!=${id})]`),
      ]);

      const undoable = makeUndoable('Removed a part', [
        Operations.replace('$.authoring', clone(model.authoring)),
        // Operations.insert('$.choices', clone(choice), index),
      ]);
      post(undoable);
    };
  },
};
