import { getChoice, getChoices } from 'components/activities/common/choices/authoring/choiceUtils';
import { noop } from 'components/activities/common/utils';
import { Choice, HasChoices, PostUndoable, RichText } from 'components/activities/types';

export const ChoiceActions = {
  addChoice(choice: Choice, post: PostUndoable = noop) {
    return (model: HasChoices) => {
      model.choices.push(choice);
    };
  },

  editChoiceContent(id: string, content: RichText) {
    return (model: HasChoices, post: PostUndoable = noop) => {
      getChoice(model, id).content = content;
    };
  },

  setAllChoices(choices: Choice[]) {
    return (model: HasChoices, post: PostUndoable = noop) => {
      model.choices = choices;
    };
  },

  removeChoice(id: string) {
    return (model: HasChoices, post: PostUndoable = noop) => {
      const choice = getChoice(model, id);
      const index = getChoices(model).findIndex((c) => c.id === id);
      model.choices = model.choices.filter((choice) => choice.id !== id);

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
};
