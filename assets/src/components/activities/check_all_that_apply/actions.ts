import { CheckAllThatApplyModelSchema as CATA, Choice, Choice as ChoiceType } from './schema';
import { addOrRemoveFromList, createRuleForIds, fromText, getChoice, getCorrectResponse, getHint, getResponse, makeResponse, getChoiceIds, getCorrectChoiceIds, getIncorrectChoiceIds, getIncorrectResponse, getTargetedChoiceIds, getTargetedResponses, getResponseId, setDifference, removeFromList, invertRule } from './utils';
import { RichText, Feedback as FeedbackType, Hint as HintType, ChoiceId } from '../types';
import { toSimpleText } from 'data/content/text';

// Update all response rules based on a model with new choices that are not yet reflected in the rules
const updateResponseRules = (model: CATA) => {

  // update correct response rule
  console.log('correct response rule before', getCorrectResponse(model).rule)
  getCorrectResponse(model).rule = createRuleForIds(
    getCorrectChoiceIds(model),
    getIncorrectChoiceIds(model));
  console.log('correct response rule after', getCorrectResponse(model).rule)

  // update incorrect response rule
  console.log('incorrect response rule before', getIncorrectResponse(model).rule)
  getIncorrectResponse(model).rule = invertRule(getCorrectResponse(model).rule);
  console.log('incorrect response rule after', getIncorrectResponse(model).rule)

  // update targeted response rules
  switch (model.type) {
    case 'SimpleCATA': return;
    case 'TargetedCATA':
      const allChoiceIds = model.choices.map(choice => choice.id);
      model.authoring.targeted.forEach(assoc =>
        getResponse(model, getResponseId(assoc)).rule = createRuleForIds(
          getChoiceIds(assoc),
          setDifference(
            allChoiceIds,
            getChoiceIds(assoc))));
      return;
  }
}

export class Actions {
  static toggleType() {
    return (model: CATA) => {
      model.type = model.type === 'SimpleCATA'
        ? 'TargetedCATA'
        : 'SimpleCATA';
    }
  }

  static editStem(content: RichText) {
    return (model: CATA) => {
      model.stem.content = content;
      const previewText = toSimpleText({ children: content.model } as any);
      model.authoring.previewText = previewText;
    };
  }

  static addChoice() {
    return (model: CATA) => {
      const newChoice: ChoiceType = fromText('');

      model.choices.push(newChoice);
      getChoiceIds(model.authoring.incorrect).push(newChoice.id);
      updateResponseRules(model);
    };
  }

  static editChoiceContent(id: string, content: RichText) {
    return (model: CATA) => {
      getChoice(model, id).content = content;
    };
  }

  static removeChoice(id: string) {
    return (model: CATA) => {
      const removeIdFrom = (list: string[]) => removeFromList(id, list);

      // remove choice from model.choices
      model.choices = model.choices.filter(choice => choice.id !== id);

      // remove choice from model.authoring.correct choice ids
      removeIdFrom(getChoiceIds(model.authoring.correct));

      // remove choice from model.authoring.incorrect choice ids
      removeIdFrom(getChoiceIds(model.authoring.incorrect));

      // if targeted, remove choice from all model.authoring.targeted
      switch (model.type) {
        case 'SimpleCATA': break;
        case 'TargetedCATA':
          model.authoring.targeted.forEach(assoc => removeIdFrom(getChoiceIds(assoc)));
      }

      // update all response rules with new choice ids
      updateResponseRules(model);
    };
  }

  // Fix this to include the full set of choices with or without the new choice
  static toggleChoiceCorrectness(choiceId: ChoiceId) {
    return (model: CATA) => {
      const addOrRemoveId = (list: string[]) => addOrRemoveFromList(choiceId, list);

      // update correct response choices
      addOrRemoveId(getChoiceIds(model.authoring.correct));

      // update incorrect response choices
      addOrRemoveId(getChoiceIds(model.authoring.incorrect));

      // targeted response choices do not need to change

      // update response rules based on new choice correctness
      updateResponseRules(model);
    };
  }

  // // generalize to work for targeted feedback too
  // // change join rules, add new helpers for inverting correct and targeted feedback
  // // input looks like "id1 id2", matches `input like {id1} && input like {id2}`
  // static editResponseCorrectness(correctChoices: Choice[], incorrectChoices : Choice[]) {
  //   return (model: CATA) => {
  //     const joinRules = (rule: string, choices: Choice[]) =>
  //     choices.map(choice => rule + choice.id).join(' || ');
  //     model.authoring.parts[0].responses.forEach((response) => {
  //       // Simple model: one correct response, one incorrect response
  //       // Could be extended here to add partial credit
  //       response.rule = joinRules(
  //         'input like ',
  //         response.score === 1
  //           ? correctChoices
  //           : incorrectChoices);
  //       console.log('response.rule', response.rule);
  //     });
  //   };
  // }

  static editCorrectFeedback(content: RichText) {
    return (model: CATA) => {
      // There is only one correct response which matches the correct combination of answer choices
      getCorrectResponse(model).feedback.content = content;
    };
  }

  static editIncorrectFeedback(content: RichText) {
    return (model: CATA) => {
      // There is only one "catch all" incorrect response which matches the inverse combination
      // of correct answer choices
      getIncorrectResponse(model).feedback.content = content;
    };
  }

  static editResponseFeedback(id: string, content: RichText) {
    return (model: CATA) => {
      getResponse(model, id).feedback.content = content;
    };
  }

  static addHint() {
    return (model: CATA) => {
      const newHint: HintType = fromText('');
      // new hints are always cognitive hints. they should be inserted
      // right before the bottomOut hint at the end of the list
      const bottomOutIndex = model.authoring.parts[0].hints.length - 1;
      model.authoring.parts[0].hints.splice(bottomOutIndex, 0, newHint);
    };
  }

  static editHint(id: string, content: RichText) {
    return (model: CATA) => {
      getHint(model, id).content = content;
    };
  }

  static removeHint(id: string) {
    return (model: CATA) => {
      model.authoring.parts[0].hints = model.authoring.parts[0].hints
      .filter(h => h.id !== id);
    };
  }
}

