import { MultipleChoiceModelSchema } from './schema';
import { Choice, makeResponse } from '../types';
import { PostUndoable } from 'components/activities/types';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { getCorrectResponse } from 'components/activities/multiple_choice/utils';
import {
  createMatchRule,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';
import { getChoice, getChoices } from 'components/activities/common/choices/authoring/choiceUtils';

export const MCActions = {
  addChoice(choice: Choice) {
    return (model: MultipleChoiceModelSchema, post: PostUndoable) => {
      ChoiceActions.addChoice(choice)(model);

      model.authoring.parts[0].responses.push(makeResponse(`input like {${choice.id}}`, 0, ''));
    };
  },

  removeChoice(id: string) {
    return (model: MultipleChoiceModelSchema, post: PostUndoable) => {
      const choice = getChoice(model, id);
      const index = getChoices(model).findIndex((c) => c.id === id);
      ChoiceActions.removeChoice(id)(model);

      model.authoring.parts[0].responses = getResponses(model).filter(
        (r) => r.rule !== createMatchRule(id),
      );

      post({
        description: 'Removed a choice',
        operations: [
          {
            path: '$.choices',
            index,
            item: JSON.parse(JSON.stringify(choice)),
          },
        ],
        type: 'Undoable',
      });
    };
  },

  toggleChoiceCorrectness(id: string) {
    return (model: MultipleChoiceModelSchema, post: PostUndoable) => {
      getCorrectResponse(model).rule = createMatchRule(id);
    };
  },
};
