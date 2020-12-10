import { OrderingModelSchema as Ordering, TargetedOrdering } from './schema';
import { createRuleForIds, fromText, getChoice, getCorrectResponse,
  getHint, getResponse, getChoiceIds, getCorrectChoiceIds, getIncorrectChoiceIds,
  getIncorrectResponse, getResponseId, setDifference, invertRule, unionRules, getResponses,
  makeResponse,
  isSimpleOrdering,
  getHints} from './utils';
import { RichText, Hint as HintType, ChoiceId, Choice, ResponseId } from '../types';
import { toSimpleText } from 'data/content/text';

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

  static editStem(content: RichText) {
    return (model: Ordering) => {
      model.stem.content = content;
      const previewText = toSimpleText({ children: content.model } as any);
      model.authoring.previewText = previewText;
    };
  }

  static addChoice() {
    return (model: Ordering) => {
      const newChoice: Choice = fromText('');

      model.choices.push(newChoice);
      getChoiceIds(model.authoring.incorrect).push(newChoice.id);
      updateResponseRules(model);
    };
  }

  static editChoiceContent(id: string, content: RichText) {
    return (model: Ordering) => {
      getChoice(model, id).content = content;
    };
  }

  static removeChoice(id: string) {
    return (model: Ordering) => {
      const removeIdFrom = (list: string[]) => removeFromList(id, list);
      model.choices = model.choices.filter(choice => choice.id !== id);
      removeIdFrom(getChoiceIds(model.authoring.correct));
      removeIdFrom(getChoiceIds(model.authoring.incorrect));

      switch (model.type) {
        case 'SimpleOrdering': break;
        case 'TargetedOrdering':
          model.authoring.targeted.forEach(assoc => removeIdFrom(getChoiceIds(assoc)));
      }

      updateResponseRules(model);
    };
  }

  static toggleChoiceCorrectness(choiceId: ChoiceId) {
    return (model: Ordering) => {
      const addOrRemoveId = (list: string[]) => addOrRemoveFromList(choiceId, list);
      // targeted response choices do not need to change

      addOrRemoveId(getChoiceIds(model.authoring.correct));
      addOrRemoveId(getChoiceIds(model.authoring.incorrect));
      updateResponseRules(model);
    };
  }

  static editResponseFeedback(responseId: ResponseId, content: RichText) {
    return (model: Ordering) => {
      getResponse(model, responseId).feedback.content = content;
    };
  }

  static addTargetedFeedback() {
    return (model: Ordering) => {
      switch (model.type) {
        case 'SimpleOrdering': return;
        case 'TargetedOrdering':
          const response = makeResponse(
            createRuleForIds([], model.choices.map(({ id }) => id)), 0, '');

          getResponses(model).push(response);
          model.authoring.targeted.push([[], response.id]);
          return;
      }
    };
  }

  static removeTargetedFeedback(responseId: ResponseId) {
    return (model: Ordering) => {
      switch (model.type) {
        case 'SimpleOrdering': return;
        case 'TargetedOrdering':
          removeFromList(getResponse(model, responseId), getResponses(model));
          removeFromList(
            model.authoring.targeted.find(assoc => getResponseId(assoc) === responseId),
            model.authoring.targeted);
      }
    };
  }

  static editTargetedFeedbackChoices(responseId: ResponseId, choiceIds: ChoiceId[]) {
    return (model: Ordering) => {
      switch (model.type) {
        case 'SimpleOrdering': break;
        case 'TargetedOrdering':
          const assoc = model.authoring.targeted.find(assoc => getResponseId(assoc) === responseId);
          if (!assoc) break;
          assoc[0] = choiceIds;
          break;
      }
      updateResponseRules(model);
    };
  }

  static addHint() {
    return (model: Ordering) => {
      const newHint: HintType = fromText('');
      // new hints are always cognitive hints. they should be inserted
      // right before the bottomOut hint at the end of the list
      const bottomOutIndex = getHints(model).length - 1;
      getHints(model).splice(bottomOutIndex, 0, newHint);
    };
  }

  static editHint(id: string, content: RichText) {
    return (model: Ordering) => {
      getHint(model, id).content = content;
    };
  }

  static removeHint(id: string) {
    return (model: Ordering) => {
      model.authoring.parts[0].hints = getHints(model).filter(h => h.id !== id);
    };
  }
}

// mutable
function addOrRemoveFromList<T>(item: T, list: T[]) {
  if (list.find(x => x === item)) {
    return removeFromList(item, list);
  }
  return list.push(item);
}
// mutable
function removeFromList<T>(item: T, list: T[]) {
  const index = list.findIndex(x => x === item);
  if (index > -1) {
    list.splice(index, 1);
  }
}

// Update all response rules based on a model with new choices that
// are not yet reflected by the rules.
const updateResponseRules = (model: Ordering) => {

  getCorrectResponse(model).rule = createRuleForIds(
    getCorrectChoiceIds(model),
    getIncorrectChoiceIds(model));

  switch (model.type) {
    case 'SimpleOrdering':
      getIncorrectResponse(model).rule = invertRule(getCorrectResponse(model).rule);
      break;
    case 'TargetedOrdering':
      const targetedRules: string[] = [];
      const allChoiceIds = model.choices.map(choice => choice.id);
      model.authoring.targeted.forEach((assoc) => {
        const targetedRule = createRuleForIds(
          getChoiceIds(assoc),
          setDifference(allChoiceIds, getChoiceIds(assoc)));
        targetedRules.push(targetedRule);
        getResponse(model, getResponseId(assoc)).rule = targetedRule;
      });
      getIncorrectResponse(model).rule = unionRules(
        targetedRules.map(invertRule)
          .concat([invertRule(getCorrectResponse(model).rule)]));
      break;
  }
};
