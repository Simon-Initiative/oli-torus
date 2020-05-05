import React, { useReducer, useEffect } from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { MultipleChoiceModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { QuestionTypeDropdown } from '../QuestionTypeDropdown';
import { Stem } from './sections/Stem';
import { Choices } from './sections/Choices';
import { Feedback } from './sections/Feedback';
import { Hints } from './sections/Hints';
import { MCReducer, MCActions } from './reducer';

const MultipleChoice = (props: AuthoringElementProps<MultipleChoiceModelSchema>) => {
  const [state, dispatch] = useReducer(MCReducer, props.model);

  useEffect(() => props.onEdit(state), [state]);

  const sharedProps = {
    model: state,
    editMode: props.editMode,
  };

  return (
    <div className="p-4 pl-5">
      <QuestionTypeDropdown {...sharedProps} />
      <Stem {...sharedProps}
        onEditStem={content => dispatch(MCActions.editStem(content))} />
      <Choices {...sharedProps}
        onAddChoice={() => dispatch(MCActions.addChoice())}
        onEditChoice={(id, content) => dispatch(MCActions.editChoice(id, content))}
        onRemoveChoice={id => dispatch(MCActions.removeChoice(id))} />
      <Feedback {...sharedProps}
        onEditFeedback={(id, content) => dispatch(MCActions.editFeedback(id, content))} />
      <Hints {...sharedProps}
        onAddHint={() => dispatch(MCActions.addHint())}
        onEditHint={(id, content) => dispatch(MCActions.editHint(id, content))}
        onRemoveHint={id => dispatch(MCActions.removeHint(id))} />
    </div>
  );
};

export class MultipleChoiceAuthoring extends AuthoringElement<MultipleChoiceModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MultipleChoiceModelSchema>) {
    ReactDOM.render(<MultipleChoice {...props} />, mountPoint);
  }
}

const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, MultipleChoiceAuthoring);
