import {
  getResponse,
  getResponseId,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';
import { remove } from 'components/activities/common/utils';
import {
  ChoiceIdsToResponseId,
  HasParts,
  PostUndoable,
  ResponseId,
  RichText,
  makeUndoable
} from 'components/activities/types';
import { clone } from 'utils/common';

export const ResponseActions = {
  editResponseFeedback(id: ResponseId, content: RichText) {
    return (model: HasParts) => {
      getResponse(model, id).feedback.content = content;
    };
  },
  removeResponse(id: ResponseId) {
    return (model: HasParts) => {
      remove(getResponse(model, id), getResponses(model));
    };
  },
  editRule(id: ResponseId, rule: string) {
    return (draftState: HasParts) => {
      getResponse(draftState, id).rule = rule;
    };
  },
  removeTargetedFeedback(responseId: ResponseId) {
    return (
      model: HasParts & { authoring: { targeted: ChoiceIdsToResponseId[] } },
      post: PostUndoable,
    ) => {

      post(makeUndoable('Removed feedback',
        [{ type: 'ReplaceOperation', path: '$.authoring', item: clone(model.authoring)}]));

      const response = getResponse(model, responseId);
      remove(response, getResponses(model));
      remove(
        model.authoring.targeted.find((assoc) => getResponseId(assoc) === responseId),
        model.authoring.targeted,
      );

    };
  },
};
