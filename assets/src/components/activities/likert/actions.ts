import { LikertModelSchema } from './schema';
import { makeHint, HasParts, Part } from '../types';
import * as ActivityTypes from '../types';
import { PostUndoable, makeUndoable } from 'components/activities/types';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';
import { Choices, Items } from 'data/activities/model/choices';
import { matchRule } from 'data/activities/model/rules';
import { MCActions } from '../common/authoring/actions/multipleChoiceActions';
import { getCorrectResponse, Responses } from 'data/activities/model/responses';

export const LikertActions = {
  addChoice() {
    return (model: any & HasParts, post: PostUndoable) => {
      Choices.addOne(ActivityTypes.makeChoice(''))(model);
    };
  },

  removeChoice(id: string) {
    return (model: any & HasParts, post: PostUndoable) => {
      const choice = Choices.getOne(model, id);
      const index = Choices.getAll(model).findIndex((c) => c.id === id);
      Choices.removeOne(id)(model);

      const authoringClone = clone(model.authoring);
      const undoable = makeUndoable('Removed a choice', [
        Operations.replace('$.authoring', authoringClone),
        Operations.insert(Choices.path, clone(choice), index),
      ]);
      post(undoable);

      // for each part where the choice being removed is the correct choice,
      // a new correct choice must be set
      model.authoring.parts.forEach((part: Part) => {
        if (getCorrectResponse(model, part.id).rule === matchRule(id)) {
          const firstChoice = Choices.getAll(model)[0];
          MCActions.toggleChoiceCorrectness(firstChoice.id, part.id)(model, post);
        }
      });
    };
  },

  addItem() {
    return (model: any & HasParts, post: PostUndoable) => {
      // add new item
      const item = ActivityTypes.makeChoice('');
      Items.addOne(item)(model);

      // add a new part associated by using same id
      const newPart = ActivityTypes.makePart(
        Responses.forMultipleChoice(model.choices[0].id),
        [makeHint(''), makeHint(''), makeHint('')],
        item.id, // use item id as part id
      );
      model.authoring.parts.push(newPart);
    };
  },

  removeItem(id: string) {
    return (model: any & HasParts, post: PostUndoable) => {
      // remove part associated with this item
      Operations.apply(model, Operations.filter('authoring.parts', `[?(@.id!=${id})]`));

      // remove the specified item
      Items.removeOne(id)(model);
    };
  },
};
