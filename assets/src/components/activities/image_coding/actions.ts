import { ImageCodingModelSchema } from './schema';
import { fromText } from './utils';
import { RichText, Hint as HintType, Choice } from '../types';
import { Maybe } from 'tsmonad';
import { toSimpleText } from 'data/content/text';
import { Identifiable } from 'data/content/model';

export class ICActions {
  private static getById<T extends Identifiable>(slice: T[], id: string): Maybe<T> {
    return Maybe.maybe(slice.find((c) => c.id === id));
  }

  private static getHint = (draftState: ImageCodingModelSchema, id: string) =>
    ICActions.getById(draftState.authoring.parts[0].hints, id);

  static editStem(content: RichText) {
    return (draftState: ImageCodingModelSchema) => {
      draftState.stem.content = content;
      const previewText = toSimpleText({ children: content.model } as any);
      draftState.authoring.previewText = previewText;
    };
  }

  static editStarterCode(text: string) {
    return (draftState: ImageCodingModelSchema) => {
      draftState.starterCode = text;
    };
  }

  static editSolutionCode(text: string) {
    return (draftState: ImageCodingModelSchema) => {
      draftState.solutionCode = text;
    };
  }

  static editIsExample(value: boolean) {
    return (draftState: ImageCodingModelSchema) => {
      draftState.isExample = value;
    };
  }

  static addResourceURL(value: string) {
    return (draftState: ImageCodingModelSchema) => {
      if (draftState.resourceURLs.indexOf(value) === -1) {
        draftState.resourceURLs.push(value);
      }
    };
  }

  static removeResourceURL(value: string) {
    return (draftState: ImageCodingModelSchema) => {
      draftState.resourceURLs = draftState.resourceURLs.filter((url) => url !== value);
    };
  }

  static editTolerance(value: number) {
    return (draftState: ImageCodingModelSchema) => {
      draftState.tolerance = value;
    };
  }

  static editRegex(value: string) {
    return (draftState: ImageCodingModelSchema) => {
      draftState.regex = value;
    };
  }

  static editFeedback(score: number, content: RichText) {
    return (draftState: ImageCodingModelSchema) => {
      draftState.feedback[score].content = content;
    };
  }

  static addHint() {
    return (draftState: ImageCodingModelSchema) => {
      const newHint: HintType = fromText('');
      // new hints are always cognitive hints. they should be inserted
      // right before the bottomOut hint at the end of the list
      const bottomOutIndex = draftState.authoring.parts[0].hints.length - 1;
      draftState.authoring.parts[0].hints.splice(bottomOutIndex, 0, newHint);
    };
  }

  static editHint(id: string, content: RichText) {
    return (draftState: ImageCodingModelSchema) => {
      ICActions.getHint(draftState, id).lift((hint) => (hint.content = content));
    };
  }

  static removeHint(id: string) {
    return (draftState: ImageCodingModelSchema) => {
      draftState.authoring.parts[0].hints = draftState.authoring.parts[0].hints.filter(
        (h) => h.id !== id,
      );
    };
  }
}
