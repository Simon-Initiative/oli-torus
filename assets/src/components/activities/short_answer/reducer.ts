import { ShortAnswerModelSchema, InputType } from './schema';
import { makeResponse } from './utils';
import { fromText } from '../common/utils';
import { RichText, Feedback as FeedbackType, Hint as HintType, Response } from '../types';
import { Maybe } from 'tsmonad';
import { Identifiable } from 'data/content/model';
import { ImmerReducer, createActionCreators, createReducerFunction } from 'immer-reducer';

class Reducer extends ImmerReducer<ShortAnswerModelSchema> {

  private getById<T extends Identifiable>(slice: T[], id: string): Maybe<T> {
    return Maybe.maybe(slice.find(c => c.id === id));
  }

  private getResponse = (id: string) => {
    return this.getById(this.draftState.authoring.parts[0].responses, id);
  }
  private getHint = (id: string) => this.getById(this.draftState.authoring.parts[0].hints, id);

  editStem(content: RichText) {
    this.draftState.stem.content = content;
  }

  editFeedback(id: string, content: RichText) {
    this.getResponse(id).lift(r => r.feedback.content = content);
  }

  editRule(id: string, rule: string) {
    this.getResponse(id).lift(r => r.rule = rule);
  }

  addResponse() {
    let rule;
    if (this.draftState.inputType === 'numeric') {
      rule = 'input = {1}';
    } else {
      rule = 'input like {another answer}';
    }

    const response: Response = makeResponse(rule, 0, '');
    // Insert a new reponse just before the last response
    const index = this.draftState.authoring.parts[0].responses.length - 1;
    this.draftState.authoring.parts[0].responses.splice(index, 0, response);
  }

  removeReponse(id: string) {
    this.draftState.authoring.parts[0].responses = this.draftState.authoring.parts[0].responses
      .filter(r => r.id !== id);
  }

  addHint() {
    const newHint: HintType = fromText('');

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

  setInputType(inputType: InputType) {

    // When we transition from numeric to text(area) or back, we reset the responses
    if (this.draftState.inputType === 'numeric' && inputType !== 'numeric') {
      this.draftState.authoring.parts[0].responses = [
        makeResponse('input like {answer}', 1, ''),
        makeResponse('input like {.*}', 0, ''),
      ];
    } else if (this.draftState.inputType !== 'numeric' && inputType === 'numeric') {
      this.draftState.authoring.parts[0].responses = [
        makeResponse('input = {1}', 1, ''),
        makeResponse('input like {.*}', 0, ''),
      ];
    }

    this.draftState.inputType = inputType;
  }
}

// immer-reducer
export const ShortAnswerActions = createActionCreators(Reducer);
export const ShortAnswerReducer = createReducerFunction(Reducer);
