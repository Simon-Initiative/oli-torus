import React, { useReducer, useEffect } from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { MultipleChoiceModelSchema, Choice as ChoiceType, Feedback as FeedbackType,
    Hint as HintType, RichText } from './schema';
import * as ActivityTypes from '../types';
import { fromText, feedback as makeFeedback } from './utils';
import { Maybe } from 'tsmonad';
import { Identifiable } from 'data/content/model';
import { ImmerReducer, createActionCreators, createReducerFunction } from 'immer-reducer';
import { QuestionTypeDropdown } from '../QuestionTypeDropdown';
import { Stem } from './sections/Stem';
import { Choices } from './sections/Choices';
import { Feedback } from './sections/Feedback';
import { Hints } from './sections/Hints';

const MultipleChoice = (props: AuthoringElementProps<MultipleChoiceModelSchema>) => {

  // immer-reducer
  const actions = createActionCreators(Reducer);
  const reducer = createReducerFunction(Reducer);

  const [state, dispatch] = useReducer(reducer, props.model);

  useEffect(() => props.onEdit(state), [state]);

  const sharedProps = {
    model: state,
    editMode: props.editMode,
  };

  return (
    <div className="p-4 pl-5">
      <QuestionTypeDropdown {...sharedProps} />
      <Stem {...sharedProps}
        onEditStem={content => dispatch(actions.editStem(content))} />
      <Choices {...sharedProps}
        onAddChoice={() => dispatch(actions.addChoice())}
        onEditChoice={(id, content) => dispatch(actions.editChoice(id, content))}
        onRemoveChoice={id => dispatch(actions.removeChoice(id))} />
      <Feedback {...sharedProps}
        onEditFeedback={(id, content) => dispatch(actions.editFeedback(id, content))} />
      <Hints {...sharedProps}
        onAddHint={() => dispatch(actions.addHint())}
        onEditHint={(id, content) => dispatch(actions.editHint(id, content))}
        onRemoveHint={id => dispatch(actions.removeHint(id))} />
    </div>
  );
};

export class MultipleChoiceAuthoring extends AuthoringElement<MultipleChoiceModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MultipleChoiceModelSchema>) {
    ReactDOM.render(<MultipleChoice {...props} />, mountPoint);
  }
}

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

const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, MultipleChoiceAuthoring);
