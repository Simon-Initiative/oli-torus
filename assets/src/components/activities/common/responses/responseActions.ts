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
} from 'components/activities/types';

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
      const response = getResponse(model, responseId);
      const index = getResponses(model).findIndex((r) => r.id === responseId);
      remove(response, getResponses(model));
      remove(
        model.authoring.targeted.find((assoc) => getResponseId(assoc) === responseId),
        model.authoring.targeted,
      );

      post({
        description: 'Removed a targeted feedback',
        operations: [
          {
            path: '$.authoring.parts[0].responses',
            index,
            item: JSON.parse(JSON.stringify(response)),
          },
        ],
        type: 'Undoable',
      });
    };
  },
};
