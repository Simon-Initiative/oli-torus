import { getResponse } from 'components/activities/common/responses/authoring/responseUtils';
import { HasParts, ResponseId, RichText } from 'components/activities/types';

export const ResponseActions = {
  editResponseFeedback(responseId: ResponseId, content: RichText) {
    return (model: HasParts) => {
      getResponse(model, responseId).feedback.content = content;
    };
  },
};
