import { Responses } from 'data/activities/model/responses';
import { getPartById } from 'data/activities/model/utils';
import { GradingApproach } from '../types';
import { InputType, ShortAnswerModelSchema } from './schema';

export const ShortAnswerActions = {
  setInputType(inputType: InputType, partId: string) {
    return (model: ShortAnswerModelSchema) => {
      if (model.inputType === inputType) return;

      if (inputType === 'text' || inputType === 'textarea') {
        getPartById(model, partId).responses = Responses.forTextInput();
      } else if (inputType === 'numeric') {
        getPartById(model, partId).responses = Responses.forNumericInput();
      }

      model.inputType = inputType;
    };
  },
  setGradingApproach(gradingApproach: GradingApproach, partId: string) {
    return (model: ShortAnswerModelSchema) => {
      getPartById(model, partId).gradingApproach = gradingApproach;
    };
  },
};
