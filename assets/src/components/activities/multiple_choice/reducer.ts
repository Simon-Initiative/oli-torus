import { MultipleChoiceModelSchema, Choice as ChoiceType, Feedback as FeedbackType,
    Hint as HintType, RichText } from './schema';
import { fromText, feedback as makeFeedback } from './utils';
import { Maybe } from 'tsmonad';
import { Identifiable } from 'data/content/model';
import { ImmerReducer, createActionCreators, createReducerFunction } from 'immer-reducer';

class Reducer extends ImmerReducer<MultipleChoiceModelSchema> {
  private getById<T extends Identifiable>(slice: T[], id: number): Maybe<T> {
    return Maybe.maybe(slice.find(c => c.id === id));
  }
  private getChoice = (id: number) => this.getById(this.draftState.choices, id);
  private getFeedback = (id: number) => this.getById(this.draftState.authoring.feedback, id);
  private getHint = (id: number) => this.getById(this.draftState.authoring.hints, id);

  editStem(content: RichText) {
    this.draftState.stem.content = content;
  }

  addChoice() {
    const newChoice: ChoiceType = fromText('');
    const newFeedback: FeedbackType = makeFeedback('', newChoice.id, 0);
    this.draftState.choices.push(newChoice);
    this.draftState.authoring.feedback.push(newFeedback);
  }

  editChoice(id: number, content: RichText) {
    this.getChoice(id).lift(choice => choice.content = content);
  }

  removeChoice(id: number) {
    this.draftState.choices = this.draftState.choices.filter(c => c.id !== id);
    this.draftState.authoring.feedback = this.draftState.authoring.feedback
      .filter(f => f.match !== id);
  }

  editFeedback(id: number, content: RichText) {
    this.getFeedback(id).lift(feedback => feedback.content = content);
  }

  addHint() {
    const newHint: HintType = fromText('');
    // new hints are always cognitive hints. they should be inserted
    // right before the bottomOut hint at the end of the list
    const bottomOutIndex = this.draftState.authoring.hints.length - 1;
    this.draftState.authoring.hints.splice(bottomOutIndex, 0, newHint);
  }

  editHint(id: number, content: RichText) {
    this.getHint(id).lift(hint => hint.content = content);
  }

  removeHint(id: number) {
    this.draftState.authoring.hints = this.draftState.authoring.hints
      .filter(h => h.id !== id);
  }
}

// immer-reducer
export const MCActions = createActionCreators(Reducer);
export const MCReducer = createReducerFunction(Reducer);
