import { MultipleChoiceModelSchema } from './schema';
import { PostUndoable } from 'components/activities/types';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { getChoice, getChoices } from 'components/activities/common/choices/authoring/choiceUtils';
import {matchRule} from 'components/activities/common/responses/authoring/rules';
import {getCorrectResponse} from 'components/activities/common/responses/authoring/responseUtils';

export const MCActions = {
  removeChoice(id: string) {
    return (model: MultipleChoiceModelSchema, post: PostUndoable) => {
      const choice = getChoice(model, id);
      const index = getChoices(model).findIndex((c) => c.id === id);
      ChoiceActions.removeChoice(id)(model, post);

      // if the choice being removed is the correct choice, a new correct choice
      // must be set
      if (getCorrectResponse(model).rule === matchRule(id)) {
        MCActions.toggleChoiceCorrectness(model.choices[0].id)(model, post);
      }

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
