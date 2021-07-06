import { ShortAnswerModelSchema, InputType } from './schema';
import { makeResponse } from '../types';
import { getResponses } from 'components/activities/common/responses/authoring/responseUtils';
import {
  containsRule,
  eqRule,
  matchRule,
} from 'components/activities/common/responses/authoring/rules';

export class ShortAnswerActions {
  static addResponse() {
    return (draftState: ShortAnswerModelSchema) => {
      // Insert a new reponse just before the last response
      getResponses(draftState).splice(
        getResponses(draftState).length - 1,
        0,
        makeResponse(
          draftState.inputType === 'numeric' ? eqRule('1') : containsRule('another answer'),
          0,
          '',
        ),
      );
    };
  }

  static setInputType(inputType: InputType, input: string | [string, string]) {
    return (draftState: ShortAnswerModelSchema) => {
      const firstInput = typeof input === 'string' ? input : input[1];
      if (draftState.inputType === 'numeric' && inputType !== 'numeric') {
        draftState.authoring.parts[0].responses = [
          makeResponse(containsRule(firstInput), 1, ''),
          makeResponse(matchRule('.*'), 0, ''),
        ];
      } else if (draftState.inputType !== 'numeric' && inputType === 'numeric') {
        draftState.authoring.parts[0].responses = [
          makeResponse(containsRule(firstInput), 1, ''),
          makeResponse(matchRule('.*'), 0, ''),
        ];
      }

      draftState.inputType = inputType;
    };
  }
}
