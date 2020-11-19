import { CheckAllThatApplyModelSchema, Choice, Choice as ChoiceType } from './schema';
import { fromText, getChoice, getCorrectResponse, getHint,
  getIncorrectResponses, getResponse, makeResponse } from './utils';
import { RichText, Feedback as FeedbackType, Hint as HintType } from '../types';
import { toSimpleText } from 'data/content/text';
import { Identifiable } from 'data/content/model';



export class Actions {
  static editStem(content: RichText) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      draftState.stem.content = content;
      const previewText = toSimpleText({ children: content.model } as any);
      draftState.authoring.previewText = previewText;
    };
  }

  static addChoice() {
    return (draftState: CheckAllThatApplyModelSchema) => {
      const newChoice: ChoiceType = fromText('');
      draftState.choices.push(newChoice);
      // change Actions to add responses for all combinations of the existing choices + new choice
      draftState.authoring.parts[0].responses.push(
        makeResponse(`input like {${newChoice.id}}`, 0, ''));
    };
  }

  static editChoiceContent(id: string, content: RichText) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      getChoice(draftState, id).lift(choice => choice.content = content);
    };
  }

  static removeChoice(id: string) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      draftState.choices = draftState.choices.filter(c => c.id !== id);
      draftState.authoring.parts[0].responses = draftState.authoring.parts[0].responses
      // change Actions to remove all combinations that match the choice id being removed
      .filter(r => r.rule !== `input like {${id}}`);

    };
  }

  // Fix this to include the full set of choices with or without the new choice
  static toggleChoiceCorrectness(choice: Choice) {
    return (draftState: CheckAllThatApplyModelSchema) => {

    };
  }

  // generalize to work for targeted feedback too
  // change join rules, add new helpers for inverting correct and targeted feedback
  // input looks like "id1 id2", matches `input like {id1} && input like {id2}`
  static editResponseCorrectness(correctChoices: Choice[], incorrectChoices : Choice[]) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      const joinRules = (rule: string, choices: Choice[]) =>
      choices.map(choice => rule + choice.id).join(' || ');
      draftState.authoring.parts[0].responses.forEach((response) => {
        // Simple model: one correct response, one incorrect response
        // Could be extended here to add partial credit
        response.rule = joinRules(
          'input like ',
          response.score === 1
            ? correctChoices
            : incorrectChoices);
        console.log('response.rule', response.rule);
      });
    };
  }

  static editCorrectFeedback(content: RichText) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      // There is only one correct response, for the correct combination of answer choices
      getCorrectResponse(draftState).feedback.content = content;
    };
  }

  static editIncorrectFeedback(content: RichText) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      // There are many incorrect responses for each combination of answer choice
      getIncorrectResponses(draftState).forEach(response =>
        response.feedback.content = content);
    };
  }

  static editResponseFeedback(id: string, content: RichText) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      getResponse(draftState, id).lift(r => r.feedback.content = content);
    };
  }

  static addHint() {
    return (draftState: CheckAllThatApplyModelSchema) => {
      const newHint: HintType = fromText('');
      // new hints are always cognitive hints. they should be inserted
      // right before the bottomOut hint at the end of the list
      const bottomOutIndex = draftState.authoring.parts[0].hints.length - 1;
      draftState.authoring.parts[0].hints.splice(bottomOutIndex, 0, newHint);
    };
  }

  static editHint(id: string, content: RichText) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      getHint(draftState, id).lift(hint => hint.content = content);
    };
  }

  static removeHint(id: string) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      draftState.authoring.parts[0].hints = draftState.authoring.parts[0].hints
      .filter(h => h.id !== id);
    };

  }
}

