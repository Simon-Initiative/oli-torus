import { CheckAllThatApplyModelSchema, Choice as ChoiceType } from './schema';
import { fromText, makeResponse } from './utils';
import { RichText, Feedback as FeedbackType, Hint as HintType } from '../types';
import { Maybe } from 'tsmonad';
import { toSimpleText } from 'data/content/text';
import { Identifiable } from 'data/content/model';

export class CATAActions {
  private static getById<T extends Identifiable>(slice: T[], id: string): Maybe<T> {
    return Maybe.maybe(slice.find(c => c.id === id));
  }
  private static getChoice = (draftState: CheckAllThatApplyModelSchema, id: string) =>
    CATAActions.getById(draftState.choices, id)
  private static getResponse = (draftState: CheckAllThatApplyModelSchema, id: string) =>
    CATAActions.getById(draftState.authoring.parts[0].responses, id)
  private static getHint = (draftState: CheckAllThatApplyModelSchema, id: string) =>
    CATAActions.getById(draftState.authoring.parts[0].hints, id)

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
      draftState.authoring.parts[0].responses.push(
        makeResponse(`input like {${newChoice.id}}`, 0, ''));
    };
  }

  static editChoice(id: string, content: RichText) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      CATAActions.getChoice(draftState, id).lift(choice => choice.content = content);
    };
  }

  static removeChoice(id: string) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      draftState.choices = draftState.choices.filter(c => c.id !== id);
      draftState.authoring.parts[0].responses = draftState.authoring.parts[0].responses
        .filter(r => r.rule !== `input like {${id}}`);
    };
  }

  static editFeedback(id: string, content: RichText) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      CATAActions.getResponse(draftState, id).lift(r => r.feedback.content = content);
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
      CATAActions.getHint(draftState, id).lift(hint => hint.content = content);
    };
  }

  static removeHint(id: string) {
    return (draftState: CheckAllThatApplyModelSchema) => {
      draftState.authoring.parts[0].hints = draftState.authoring.parts[0].hints
      .filter(h => h.id !== id);
    };

  }
}

