import {
  getResponse,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';
import { remove } from 'components/activities/common/utils';
import { HasParts, ResponseId, RichText } from 'components/activities/types';

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
};
