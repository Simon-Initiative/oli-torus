import { ShortAnswerModelSchema, InputType } from './schema';
import { containsRule, eqRule, matchRule } from 'data/activities/model/rules';
import { makeResponse } from 'components/activities/types';
import { getPartById } from 'data/activities/model/utils1';

export const ShortAnswerActions = {
  setInputType(inputType: InputType, partId: string, input: string | [string, string] = '') {
    return (model: ShortAnswerModelSchema) => {
      // Numeric inputs can have two inputs to support the "between" rule
      const firstInput = typeof input === 'string' ? input : input[1];
      if (inputType === 'text' || inputType === 'textarea') {
        getPartById(model, partId).responses = [
          makeResponse(containsRule(firstInput), 1, ''),
          makeResponse(matchRule('.*'), 0, ''),
        ];
      } else if (inputType === 'numeric') {
        getPartById(model, partId).responses = [
          makeResponse(eqRule('1'), 1, ''),
          makeResponse(matchRule('.*'), 0, ''),
        ];
      }

      model.inputType = inputType;
    };
  },
};
