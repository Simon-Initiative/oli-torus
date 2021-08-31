import { CHOICES_PATH } from 'components/activities/common/choices/authoring/choiceUtils';
import { Choice, PostUndoable, RichText } from 'components/activities/types';
import { Operations } from 'utils/pathOperations';

export const ChoiceActions = {
  addChoice(choice: Choice, path = CHOICES_PATH) {
    return (model: any, _post: PostUndoable) => {
      Operations.apply(model, Operations.insert(path, choice, -1));
    };
  },

  editChoiceContent(id: string, content: RichText, path = CHOICES_PATH) {
    return (model: any, _post: PostUndoable) => {
      Operations.apply(model, Operations.replace(`$..choices[?(@.id==${id})].content`, content));
    };
  },

  setAllChoices(choices: Choice[], path = CHOICES_PATH) {
    return (model: any, _post: PostUndoable) => {
      Operations.apply(model, Operations.replace(path, choices));
    };
  },

  removeChoice(id: string, path = CHOICES_PATH) {
    return (model: any, _post: PostUndoable) => {
      Operations.apply(model, Operations.filter(path, `[?(@.id!=${id})]`));
    };
  },
};
