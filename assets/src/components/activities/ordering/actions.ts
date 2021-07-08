import { OrderingModelSchema as Ordering } from './schema';
import { RichText, Hint as HintType, ChoiceId, Choice, ResponseId } from '../types';
import { toSimpleText } from 'data/content/text';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import {
  andRules,
  createRuleForIds,
  invertRule,
} from 'components/activities/common/responses/authoring/rules';
import {  isSimpleOrdering  } from 'components/activities/ordering/utils';
import {  getChoiceIds  } from 'components/activities/check_all_that_apply/utils';
import {  getChoice  } from 'components/activities/common/choices/authoring/choiceUtils';

export class Actions {
  static toggleType() {
    return (model: Ordering) => {
      if (isSimpleOrdering(model)) {
        (model as any).type = 'TargetedOrdering';
        (model as any).authoring.targeted = [];
        return;
      }

      (model as any).type = 'SimpleOrdering';
      delete (model as any).authoring.targeted;
    };
  }

  static addChoice(choice: Choice) {
    return (model: CATA, post: PostUndoable) => {
      ChoiceActions.addChoice(choice)(model, post);

      getChoiceIds(model.authoring.incorrect).push(choice.id);
      updateResponseRules(model);
    };
  }

  static removeChoice(id: ChoiceId) {
    return (model: Ordering) => {
      const removeIdFrom = (list: ChoiceId[]) => removeFromList(id, list);
      model.choices = model.choices.filter((choice) => choice.id !== id);
      removeIdFrom(getChoiceIds(model.authoring.correct));

      switch (model.type) {
        case 'SimpleOrdering':
          break;
        case 'TargetedOrdering':
          model.authoring.targeted.forEach((assoc) => {
            removeIdFrom(getChoiceIds(assoc));
            // remove targeted feedback choice ids if they match the correct answer
            if (
              getChoiceIds(assoc).every(
                (id1, index) => getCorrectOrdering(model).findIndex((id2) => id1 === id2) === index,
              )
            ) {
              assoc[0] = [];
            }
          });
          break;
      }

      updateResponseRules(model);
    };
  }

  static addTargetedFeedback() {
    return (model: Ordering) => {
      switch (model.type) {
        case 'SimpleOrdering':
          return;
        case 'TargetedOrdering':
          // eslint-disable-next-line
          const response = makeResponse(
            createRuleForIds(
              model.choices.map((c) => c.id),
              [],
            ),
            0,
            '',
          );

          getResponses(model).push(response);
          model.authoring.targeted.push([[], response.id]);
          return;
      }
    };
  }

  static removeTargetedFeedback(responseId: ResponseId) {
    return (model: Ordering) => {
      switch (model.type) {
        case 'SimpleOrdering':
          return;
        case 'TargetedOrdering':
          removeFromList(getResponse(model, responseId), getResponses(model));
          removeFromList(
            model.authoring.targeted.find((assoc) => getResponseId(assoc) === responseId),
            model.authoring.targeted,
          );
      }
    };
  }

  static editTargetedFeedbackChoices(responseId: ResponseId, choiceIds: ChoiceId[]) {
    return (model: Ordering) => {
      switch (model.type) {
        case 'SimpleOrdering':
          break;
        case 'TargetedOrdering':
          // eslint-disable-next-line
          const assoc = model.authoring.targeted.find(
            (assoc) => getResponseId(assoc) === responseId,
          );
          if (!assoc) break;
          assoc[0] = choiceIds;
          break;
      }
      updateResponseRules(model);
    };
  }
}

// Update all response rules based on a model with new choices that
// are not yet reflected by the rules.
const updateResponseRules = (model: Ordering) => {
  getCorrectResponse(model).rule = createRuleForIds(getCorrectOrdering(model), []);

  switch (model.type) {
    case 'SimpleOrdering':
      getIncorrectResponse(model).rule = invertRule(getCorrectResponse(model).rule);
      return;
    case 'TargetedOrdering':
      // eslint-disable-next-line
      const targetedRules: string[] = [];
      model.authoring.targeted.forEach((assoc) => {
        const targetedRule = createRuleForIds(getChoiceIds(assoc), []);
        targetedRules.push(targetedRule);
        getResponse(model, getResponseId(assoc)).rule = targetedRule;
      });
      getIncorrectResponse(model).rule = andRules(
        ...targetedRules.map(invertRule).concat([invertRule(getCorrectResponse(model).rule)]),
      );
      return;
  }
};
