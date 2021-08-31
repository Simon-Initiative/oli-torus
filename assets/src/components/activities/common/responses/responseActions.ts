import { getResponsesByPartId } from './authoring/responseUtils';
import jp from 'jsonpath';
import {
  getResponseBy,
  getResponseId,
  RESPONSES_PATH,
} from 'components/activities/common/responses/authoring/responseUtils';
import { remove } from 'components/activities/common/utils';
import {
  ChoiceIdsToResponseId,
  HasParts,
  PostUndoable,
  ResponseId,
  RichText,
  makeUndoable,
  Response,
} from 'components/activities/types';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';

export const ResponseActions = {
  addResponse(response: Response, partId: string, path = RESPONSES_PATH) {
    return (model: HasParts) => {
      // Insert a new reponse just before the last response (which is the catch-all response)
      jp.apply(model, path, (responses: Response[]) => {
        responses.splice(getResponsesByPartId(model, partId).length - 1, 0, response);
        return responses;
      });
    };
  },

  editResponseFeedback(id: ResponseId, content: RichText) {
    return (model: HasParts) => {
      getResponseBy(model, (r) => r.id === id).feedback.content = content;
    };
  },

  removeResponse(id: ResponseId, path = RESPONSES_PATH) {
    return (model: HasParts) => {
      jp.apply(model, path, (responses: Response[]) =>
        responses.filter((response: any) => response.id !== id),
      );
    };
  },

  editRule(id: ResponseId, rule: string) {
    return (draftState: HasParts) => {
      getResponseBy(draftState, (r) => r.id === id).rule = rule;
    };
  },

  removeTargetedFeedback(responseId: ResponseId, path = RESPONSES_PATH) {
    return (
      model: HasParts & { authoring: { targeted: ChoiceIdsToResponseId[] } },
      post: PostUndoable,
    ) => {
      post(
        makeUndoable('Removed feedback', [
          Operations.replace('$.authoring', clone(model.authoring)),
        ]),
      );

      ResponseActions.removeResponse(responseId, path)(model);
      remove(
        model.authoring.targeted.find((assoc) => getResponseId(assoc) === responseId),
        model.authoring.targeted,
      );
    };
  },
};
