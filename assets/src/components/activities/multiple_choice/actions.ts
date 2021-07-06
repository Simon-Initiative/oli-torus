import { MultipleChoiceModelSchema } from './schema';
import { Choice, makeResponse } from '../types';
import { PostUndoable } from 'components/activities/types';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { matchRule } from 'components/activities/common/responses/authoring/rules';
import { getChoice, getChoices } from 'components/activities/common/choices/authoring/choiceUtils';
import {
  getCorrectResponse,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';

export const MCActions = {
  addChoice(choice: Choice) {
    return (model: MultipleChoiceModelSchema, post: PostUndoable) => {
      ChoiceActions.addChoice(choice)(model, post);

      model.authoring.parts[0].responses.push(makeResponse(matchRule(choice.id), 0, ''));
    };
  },

  removeChoice(id: string) {
    return (model: MultipleChoiceModelSchema, post: PostUndoable) => {
      const choice = getChoice(model, id);
      const index = getChoices(model).findIndex((c) => c.id === id);
      ChoiceActions.removeChoice(id)(model, post);

      model.authoring.parts[0].responses = getResponses(model).filter(
        (r) => r.rule !== matchRule(id),
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
      getCorrectResponse(model).rule = matchRule(id);
    };
  },
};
