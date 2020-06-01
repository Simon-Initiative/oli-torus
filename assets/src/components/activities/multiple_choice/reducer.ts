import { MultipleChoiceModelSchema, Choice as ChoiceType } from './schema';
import { fromText, makeResponse } from './utils';
import { RichText, Feedback as FeedbackType, Hint as HintType } from '../types';
import { Maybe } from 'tsmonad';
import { Identifiable } from 'data/content/model';
import { ImmerReducer, createActionCreators, createReducerFunction } from 'immer-reducer';

class Reducer extends ImmerReducer<MultipleChoiceModelSchema> {
  private getById<T extends Identifiable>(slice: T[], id: string): Maybe<T> {
    return Maybe.maybe(slice.find(c => c.id === id));
  }
  private getChoice = (id: string) => this.getById(this.draftState.choices, id);
  private getResponse = (id: string) => {
    return this.getById(this.draftState.authoring.parts[0].responses, id);
  }
  private getHint = (id: string) => this.getById(this.draftState.authoring.parts[0].hints, id);

  editStem(content: RichText) {
    this.draftState.stem.content = content;
  }

  addChoice() {
    const newChoice: ChoiceType = fromText('');
    this.draftState.choices.push(newChoice);
    this.draftState.authoring.parts[0].responses.push(
      makeResponse(`input like {${newChoice.id}}`, 0, ''));
  }

  editChoice(id: string, content: RichText) {
    this.getChoice(id).lift(choice => choice.content = content);
  }

  removeChoice(id: string) {
    this.draftState.choices = this.draftState.choices.filter(c => c.id !== id);
    this.draftState.authoring.parts[0].responses = this.draftState.authoring.parts[0].responses
      .filter(r => r.rule !== `input like {${id}}`);
  }

  editFeedback(id: string, content: RichText) {
    this.getResponse(id).lift(r => r.feedback.content = content);
  }

  addHint() {
    const newHint: HintType = fromText('');
    // new hints are always cognitive hints. they should be inserted
    // right before the bottomOut hint at the end of the list
    const bottomOutIndex = this.draftState.authoring.parts[0].hints.length - 1;
    this.draftState.authoring.parts[0].hints.splice(bottomOutIndex, 0, newHint);
  }

  editHint(id: string, content: RichText) {
    this.getHint(id).lift(hint => hint.content = content);
  }

  removeHint(id: string) {
    this.draftState.authoring.parts[0].hints = this.draftState.authoring.parts[0].hints
      .filter(h => h.id !== id);
  }
}

// immer-reducer
export const MCActions = createActionCreators(Reducer);
export const MCReducer = createReducerFunction(Reducer);
