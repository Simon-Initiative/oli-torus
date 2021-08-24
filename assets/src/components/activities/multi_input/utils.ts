import { MultiInputSchema, MultiInput } from './schema';
import { HasParts, makeStem, makeTransformation, Operation } from '../types';
import {
  getCorrectResponse,
  getIncorrectResponse,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';

export const defaultModel: () => MultiInputSchema = () => {
  return {
    stems: [makeStem('')],
    inputs: [] as MultiInput[],
    authoring: {
      parts: [],
      targeted: [],
      transformations: [makeTransformation('choices', Operation.shuffle)],
      previewText: '',
    },
  };
};

export const getTargetedResponses = (model: HasParts) =>
  getResponses(model).filter(
    (response) =>
      response !== getCorrectResponse(model) && response !== getIncorrectResponse(model),
  );
