import React from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { MultipleChoiceModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Stem } from '../common/Stem';
import { Choices } from './sections/Choices';
import { Feedback } from './sections/Feedback';
import { Hints } from '../common/Hints';
import { MCActions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import produce from 'immer';

const store = configureStore();

const MultipleChoice = (props: AuthoringElementProps<MultipleChoiceModelSchema>) => {
  const dispatch = (action: any) => {
    const nextModel = produce(props.model, (draftState) => action(draftState));
    props.onEdit(nextModel);
  };

  const { projectSlug } = props;

  const sharedProps = {
    model: props.model,
    editMode: props.editMode,
    projectSlug,
  };

  return (
    <React.Fragment>
      <Stem
        projectSlug={props.projectSlug}
        editMode={props.editMode}
        stem={props.model.stem}
        onEditStem={(content) => dispatch(MCActions.editStem(content))}
      />
      <Choices
        {...sharedProps}
        onAddChoice={() => dispatch(MCActions.addChoice())}
        onEditChoice={(id, content) => dispatch(MCActions.editChoice(id, content))}
        onRemoveChoice={(id) => dispatch(MCActions.removeChoice(id))}
      />
      <Feedback
        {...sharedProps}
        onEditResponse={(id, content) => dispatch(MCActions.editFeedback(id, content))}
      />
      <Hints
        projectSlug={props.projectSlug}
        hints={props.model.authoring.parts[0].hints}
        editMode={props.editMode}
        onAddHint={() => dispatch(MCActions.addHint())}
        onEditHint={(id, content) => dispatch(MCActions.editHint(id, content))}
        onRemoveHint={(id) => dispatch(MCActions.removeHint(id))}
      />
    </React.Fragment>
  );
};

export class MultipleChoiceAuthoring extends AuthoringElement<MultipleChoiceModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MultipleChoiceModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <MultipleChoice {...props} />
        <ModalDisplay />
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, MultipleChoiceAuthoring);
