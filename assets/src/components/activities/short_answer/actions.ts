import { ShortAnswerModelSchema, InputType } from './schema';
import { containsRule, eqRule, matchRule } from 'data/activities/model/rules';
import { makeResponse } from 'components/activities/types';

export const ShortAnswerActions = {
  setInputType(inputType: InputType, input: string | [string, string] = '') {
    return (model: ShortAnswerModelSchema) => {
      // Numeric inputs can have two inputs to support the "between" rule
      const firstInput = typeof input === 'string' ? input : input[1];
      if (model.inputType === 'numeric' && inputType !== 'numeric') {
        model.authoring.parts[0].responses = [
          makeResponse(containsRule(firstInput), 1, ''),
          makeResponse(matchRule('.*'), 0, ''),
        ];
      } else if (model.inputType !== 'numeric' && inputType === 'numeric') {
        model.authoring.parts[0].responses = [
          makeResponse(eqRule('1'), 1, ''),
          makeResponse(matchRule('.*'), 0, ''),
        ];
      }

      model.inputType = inputType;
    };
  },
};
