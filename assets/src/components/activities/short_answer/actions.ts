import { ShortAnswerModelSchema, InputType } from './schema';
import { fromText } from '../common/utils';
import { RichText, Hint as HintType, Response, makeResponse } from '../types';
import { Maybe } from 'tsmonad';
import { toSimpleText } from 'data/content/text';
import { Identifiable } from 'data/content/model';
import { getResponse } from 'components/activities/common/responses/authoring/responseUtils';

export class ShortAnswerActions {
  static setModel(model: ShortAnswerModelSchema) {
    return (draftState: ShortAnswerModelSchema) => {
      draftState.authoring = model.authoring;
      draftState.inputType = model.inputType;
      draftState.stem = model.stem;
    };
  }

  static editFeedback(id: string, content: RichText) {
    return (draftState: ShortAnswerModelSchema) => {
      getResponse(draftState, id).feedback.content = content;
    };
  }

  static editRule(id: string, rule: string) {
    return (draftState: ShortAnswerModelSchema) => {
      getResponse(draftState, id).rule = rule;
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
      draftState.authoring.parts[0].responses = draftState.authoring.parts[0].responses.filter(
        (r) => r.id !== id,
      );
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
