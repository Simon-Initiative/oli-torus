import { ShortAnswerModelSchema, InputType } from './schema';
import { makeResponse } from './utils';
import { fromText } from '../common/utils';
import { RichText, Hint as HintType, Response } from '../types';
import { Maybe } from 'tsmonad';
import { toSimpleText } from 'data/content/text';
import { Identifiable } from 'data/content/model';

export class ShortAnswerActions {

  private static getById<T extends Identifiable>(slice: T[], id: string): Maybe<T> {
    return Maybe.maybe(slice.find(c => c.id === id));
  }

  private static getResponse = (draftState: ShortAnswerModelSchema, id: string) => {
    return ShortAnswerActions.getById(draftState.authoring.parts[0].responses, id);
  }
  private static getHint = (draftState: ShortAnswerModelSchema,
    id: string) => ShortAnswerActions.getById(draftState.authoring.parts[0].hints, id)

  static setModel(model: ShortAnswerModelSchema) {
    return (draftState: ShortAnswerModelSchema) => {
      draftState.authoring = model.authoring;
      draftState.inputType = model.inputType;
      draftState.stem = model.stem;
    };
  }

  static editStem(content: RichText) {
    return (draftState: ShortAnswerModelSchema) => {
      draftState.stem.content = content;
      draftState.authoring.previewText = toSimpleText({ children: content });
    };
  }

  static editFeedback(id: string, content: RichText) {
    return (draftState: ShortAnswerModelSchema) => {
      ShortAnswerActions.getResponse(draftState, id).lift(r => r.feedback.content = content);
    };

  }

  static editRule(id: string, rule: string) {
    return (draftState: ShortAnswerModelSchema) => {
      ShortAnswerActions.getResponse(draftState, id).lift(r => r.rule = rule);
    };
  }

  static addResponse() {
    return (draftState: ShortAnswerModelSchema) => {
      let rule;
      if (draftState.inputType === 'numeric') {
        rule = 'input = {1}';
      } else {
        rule = 'input like {another answer}';
      }

      const response: Response = makeResponse(rule, 0, '');
      // Insert a new reponse just before the last response
      const index = draftState.authoring.parts[0].responses.length - 1;
      draftState.authoring.parts[0].responses.splice(index, 0, response);
    };

  }

  static removeReponse(id: string) {
    return (draftState: ShortAnswerModelSchema) => {
      draftState.authoring.parts[0].responses = draftState.authoring.parts[0].responses
      .filter(r => r.id !== id);
    };

  }

  static addHint() {
    return (draftState: ShortAnswerModelSchema) => {
      const newHint: HintType = fromText('');

      const bottomOutIndex = draftState.authoring.parts[0].hints.length - 1;
      draftState.authoring.parts[0].hints.splice(bottomOutIndex, 0, newHint);
    };

  }

  static editHint(id: string, content: RichText) {
    return (draftState: ShortAnswerModelSchema) => {
      ShortAnswerActions.getHint(draftState, id).lift(hint => hint.content = content);
    };

  }

  static removeHint(id: string) {
    return (draftState: ShortAnswerModelSchema) => {
      draftState.authoring.parts[0].hints = draftState.authoring.parts[0].hints
      .filter(h => h.id !== id);
    };

  }

  static setInputType(inputType: InputType) {
    return (draftState: ShortAnswerModelSchema) => {
      // When we transition from numeric to text(area) or back, we reset the responses
      if (draftState.inputType === 'numeric' && inputType !== 'numeric') {
        draftState.authoring.parts[0].responses = [
          makeResponse('input like {answer}', 1, ''),
          makeResponse('input like {.*}', 0, ''),
        ];
      } else if (draftState.inputType !== 'numeric' && inputType === 'numeric') {
        draftState.authoring.parts[0].responses = [
          makeResponse('input = {1}', 1, ''),
          makeResponse('input like {.*}', 0, ''),
        ];
      }

      draftState.inputType = inputType;
    };

  }
}

