import { getChoice } from 'components/activities/common/choices/authoring/choiceUtils';
import { Choice, HasChoices, PostUndoable, RichText } from 'components/activities/types';

export const ChoiceActions = {
  addChoice(choice: Choice) {
    return (model: HasChoices, post: PostUndoable) => {
      model.choices.push(choice);
    };
  },

  editChoiceContent(id: string, content: RichText) {
    return (model: HasChoices, post: PostUndoable) => {
      getChoice(model, id).content = content;
    };
  },

  setAllChoices(choices: Choice[]) {
    return (model: HasChoices, post: PostUndoable) => {
      model.choices = choices;
    };
  },

  removeChoice(id: string) {
    return (model: HasChoices, post: PostUndoable) => {
      model.choices = model.choices.filter((choice) => choice.id !== id);
    };
  },
};
