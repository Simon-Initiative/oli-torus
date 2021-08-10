import { DropdownModelSchema } from './schema';
import { makeResponse } from '../types';
import { getResponses } from 'components/activities/common/responses/authoring/responseUtils';
import {
  containsRule,
  eqRule,
  matchRule,
} from 'components/activities/common/responses/authoring/rules';

export class DropdownActions {
  static addResponse() {
    return (draftState: DropdownModelSchema) => {
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
}
