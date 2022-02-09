import { ImageCodingModelSchema } from './schema';
import { RichText, Hint as HintType, makeHint } from '../types';
import { Maybe } from 'tsmonad';
import { Identifiable } from 'data/content/model/other';
import { PostUndoable, makeUndoable } from 'components/activities/types';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';
import { toSimpleText } from 'components/editing/utils';
import { Descendant } from 'slate';

export class ICActions {
  private static getById<T extends Identifiable>(slice: T[], id: string): Maybe<T> {
    return Maybe.maybe(slice.find((c) => c.id === id));
  }

  private static getHint = (draftState: ImageCodingModelSchema, id: string) =>
    ICActions.getById(draftState.authoring.parts[0].hints, id);

  static editStem(content: RichText) {
    return (draftState: ImageCodingModelSchema, _post: PostUndoable) => {
      draftState.stem.content = content;
      const previewText = toSimpleText(content);
      draftState.authoring.previewText = previewText;
    };
  }

  static editStarterCode(text: string) {
    return (draftState: ImageCodingModelSchema, _post: PostUndoable) => {
      draftState.starterCode = text;
    };
  }

  static editSolutionCode(text: string) {
    return (draftState: ImageCodingModelSchema, _post: PostUndoable) => {
      draftState.solutionCode = text;
    };
  }

  static editIsExample(value: boolean) {
    return (draftState: ImageCodingModelSchema, _post: PostUndoable) => {
      draftState.isExample = value;
    };
  }

  static addResourceURL(value: string) {
    return (draftState: ImageCodingModelSchema, _post: PostUndoable) => {
      if (draftState.resourceURLs.indexOf(value) === -1) {
        draftState.resourceURLs.push(value);
      }
    };
  }

  static removeResourceURL(value: string) {
    return (draftState: ImageCodingModelSchema, post: PostUndoable) => {
      const index = draftState.resourceURLs.findIndex((url) => url === value);
      const item = draftState.resourceURLs[index];
      post(
        makeUndoable('Removed a file', [Operations.insert('$.resourceURLs', clone(item), index)]),
      );

      draftState.resourceURLs = draftState.resourceURLs.filter((url) => url !== value);
    };
  }

  static editTolerance(value: number) {
    return (draftState: ImageCodingModelSchema, _post: PostUndoable) => {
      draftState.tolerance = value;
    };
  }

  static editRegex(value: string) {
    return (draftState: ImageCodingModelSchema, _post: PostUndoable) => {
      draftState.regex = value;
    };
  }

  static editFeedback(score: number, content: Descendant[]) {
    return (draftState: ImageCodingModelSchema, _post: PostUndoable) => {
      draftState.feedback[score].content = content as RichText;
    };
  }

  static addCognitiveHint() {
    return (draftState: ImageCodingModelSchema, _post: PostUndoable) => {
      const newHint: HintType = makeHint('');
      // new hints are always cognitive hints. they should be inserted
      // right before the bottomOut hint at the end of the list
      const bottomOutIndex = draftState.authoring.parts[0].hints.length - 1;
      draftState.authoring.parts[0].hints.splice(bottomOutIndex, 0, newHint);
    };
  }

  static editHint(id: string, content: RichText) {
    return (draftState: ImageCodingModelSchema, _post: PostUndoable) => {
      ICActions.getHint(draftState, id).lift((hint) => (hint.content = content));
    };
  }

  static removeHint(id: string) {
    return (draftState: ImageCodingModelSchema, post: PostUndoable) => {
      const hint = draftState.authoring.parts[0].hints.find((h) => h.id === id);
      const index = draftState.authoring.parts[0].hints.findIndex((h) => h.id === id);
      post(
        makeUndoable('Removed a hint', [
          Operations.insert('$.authoring.parts[0].hints', clone(hint), index),
        ]),
      );

      draftState.authoring.parts[0].hints = draftState.authoring.parts[0].hints.filter(
        (h) => h.id !== id,
      );
    };
  }
}
