import { remove } from 'components/activities/common/utils';
import { updateRule } from 'components/activities/response_multi/rules';
import {
  ChoiceIdsToResponseId,
  HasParts,
  MatchStyle,
  PostUndoable,
  Response,
  ResponseId,
  RichText,
  makeUndoable,
} from 'components/activities/types';
import {
  RESPONSES_PATH,
  findResponsePartId,
  getIncorrectPoints,
  getMaxPoints,
  getResponseBy,
  getResponseId,
  getResponsesByPartId,
} from 'data/activities/model/responses';
import { getParts } from 'data/activities/model/utils';
import { EditorType } from 'data/content/resource';
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

  editResponseFeedbackTextDirection(responseId: ResponseId, direction: 'ltr' | 'rtl') {
    return (model: HasParts) => {
      getResponseBy(model, (r) => r.id === responseId).feedback.textDirection = direction;
    };
    0;
  },

  editResponseFeedbackEditor(responseId: ResponseId, editor: EditorType) {
    return (model: HasParts) => {
      getResponseBy(model, (r) => r.id === responseId).feedback.editor = editor;
    };
  },

  editResponseFeedback(responseId: ResponseId, content: RichText) {
    return (model: HasParts) => {
      getResponseBy(model, (r) => r.id === responseId).feedback.content = content;
    };
  },

  editResponseScore(responseId: ResponseId, score: number) {
    return (model: HasParts) => {
      // ensure score is within allowed range
      const partId = findResponsePartId(model, responseId);
      if (
        partId &&
        getIncorrectPoints(model, partId) <= score &&
        score <= getMaxPoints(model, partId)
      )
        getResponseBy(model, (r) => r.id === responseId).score = score;
    };
  },

  editResponseMatchStyle(responseId: ResponseId, matchStyle: MatchStyle) {
    return (model: HasParts) => {
      const r = getResponseBy(model, (r) => r.id === responseId);
      r.matchStyle = matchStyle;
      // force regeneration of existing rule with new match style, no additions/modifications
      // On change to 'all' type will ensure dropdown inputs have only one selected choice
      r.rule = updateRule(r.rule, matchStyle, '', '', 'setStyle');
    };
  },

  editResponseCorrectness(responseId: ResponseId, correct: boolean) {
    return (model: HasParts) => {
      getResponseBy(model, (r) => r.id === responseId).score = correct ? 1 : 0;
    };
  },

  editShowPage(responseId: ResponseId, showPage: number | undefined) {
    return (model: HasParts) => {
      getResponseBy(model, (r) => r.id === responseId).showPage = showPage;
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
