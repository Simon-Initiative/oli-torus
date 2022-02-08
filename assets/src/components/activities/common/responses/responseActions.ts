import { remove } from 'components/activities/common/utils';
import {
  ChoiceIdsToResponseId,
  HasParts,
  makeUndoable,
  PostUndoable,
  Response,
  ResponseId,
  RichText,
} from 'components/activities/types';
import {
  getResponseBy,
  getResponseId,
  getResponsesByPartId,
  RESPONSES_PATH,
} from 'data/activities/model/responses';
import { getParts } from 'data/activities/model/utils';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';

export const ResponseActions = {
  addResponse(response: Response, partId: string, _path = RESPONSES_PATH) {
    return (model: HasParts) => {
      // Insert a new reponse just before the last response (which is the catch-all response)
      const responses = getResponsesByPartId(model, partId);
      getResponsesByPartId(model, partId).splice(responses.length - 1, 0, response);
    };
  },

  editResponseFeedback(responseId: ResponseId, content: RichText) {
    return (model: HasParts) => {
      getResponseBy(model, (r) => r.id === responseId).feedback.content = content;
    };
  },

  removeResponse(responseId: ResponseId, _path = RESPONSES_PATH) {
    return (model: HasParts) => {
      getParts(model).forEach((part) => {
        if (part.responses.find(({ id }) => id === responseId)) {
          part.responses = part.responses.filter(({ id }) => id !== responseId);
        }
      });
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
