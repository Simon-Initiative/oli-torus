import { PostUndoable, makeUndoable } from 'components/activities/types';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';

export const VariableActions = {
  onUpdateTransformations(transformations: any) {
    return (model: any, post: PostUndoable) => {
      const authoringClone = clone(model.authoring);
      model.authoring.transformations = transformations;

      if (authoringClone.transformations.length > transformations.length) {
        const undoable = makeUndoable('Disabled dynamic variables', [
          Operations.replace('$.authoring.transformations', authoringClone.transformations),
        ]);
        post(undoable);
      }
    };
  },
};
