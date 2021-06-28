import { MultipleChoiceModelSchema } from './schema';
import { Choice, makeResponse } from '../types';
import { PostUndoable } from 'components/activities/types';
import { noop } from 'components/activities/common/utils';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { getCorrectResponse } from 'components/activities/multiple_choice/utils';
import {
  createMatchRule,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';

export const MCActions = {
  addChoice(choice: Choice) {
    return (model: MultipleChoiceModelSchema, post: PostUndoable = noop) => {
      ChoiceActions.addChoice(choice)(model);

      model.authoring.parts[0].responses.push(makeResponse(`input like {${choice.id}}`, 0, ''));
    };
  },

  removeChoice(id: string) {
    return (model: MultipleChoiceModelSchema, post: PostUndoable = noop) => {
      ChoiceActions.removeChoice(id)(model);

      model.authoring.parts[0].responses = getResponses(model).filter(
        (r) => r.rule !== createMatchRule(id),
      );
    };
  },

  toggleChoiceCorrectness(id: string) {
    return (model: MultipleChoiceModelSchema, post: PostUndoable = noop) => {
      getCorrectResponse(model).rule = createMatchRule(id);
    };
  },
};