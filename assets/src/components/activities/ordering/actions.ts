import { OrderingModelSchema as Ordering, TargetedOrdering } from './schema';
import { createRuleForIds, fromText, getChoice, getCorrectResponse,
  getHint, getResponse, getChoiceIds, getCorrectChoiceIds, getIncorrectChoiceIds,
  getIncorrectResponse, getResponseId, setDifference, invertRule, unionRules, getResponses,
  makeResponse,
  isSimpleOrdering,
  getHints,
  getChoiceIndex,
  ChoiceMoveDirection,
  canMoveChoiceUp,
  canMoveChoiceDown} from './utils';
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

  // FIX
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

  // FIX
  static removeChoice(id: ChoiceId) {
    return (model: Ordering) => {
      const removeIdFrom = (list: ChoiceId[]) => removeFromList(id, list);
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

  static moveChoice(direction: ChoiceMoveDirection, id: ChoiceId) {
    return (model: Ordering) => {
      const thisChoiceIndex = getChoiceIndex(model, id);

      const swap = (index1: number, index2: number) => {
        const temp = model.choices[index1];
        model.choices[index1] = model.choices[index2];
        model.choices[index2] = temp;
      }
      const moveUp = () => swap(thisChoiceIndex, thisChoiceIndex - 1)
      const moveDown = () => swap(thisChoiceIndex, thisChoiceIndex + 1)

      switch (direction) {
        case 'up': return canMoveChoiceUp(model, id) ? moveUp() : model;
        case 'down': return canMoveChoiceDown(model, id) ? moveDown() : model;
      }
    }
  }

  static editResponseFeedback(responseId: ResponseId, content: RichText) {
    return (model: Ordering) => {
      getResponse(model, responseId).feedback.content = content;
    };
  }

  // FIX
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

  // FIX?
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

// FIX
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
