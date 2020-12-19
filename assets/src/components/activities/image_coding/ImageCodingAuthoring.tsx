import React from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { ImageCodingModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Stem } from '../common/Stem';
import { Hints } from '../common/Hints';
import { ICActions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import produce from 'immer';
import { Heading } from 'components/misc/Heading';

const store = configureStore();

const ImageCoding = (props: AuthoringElementProps<ImageCodingModelSchema>) => {

  const dispatch = (action: any) => {
    const nextModel = produce(props.model, draftState => action(draftState));
    props.onEdit(nextModel);
  };

  const { projectSlug, model } = props;

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
        stem={model.stem}
        onEditStem={content => dispatch(ICActions.editStem(content))} />

      <Heading title="Starter Code" id="starter-code" />
      <textarea
        rows={5}
        cols={80}
        className="form-control"
        value={model.starterCode}
        onChange={(e: any) => dispatch(ICActions.editStarterCode(e.target.value))} />

      <div className="form-check mb-2">
        <input
          className="form-check-input"
          type="checkbox"
          id="example-toggle"
          aria-label="Checkbox for example"
          checked={model.isExample}
          onChange={(e: any) => dispatch(ICActions.editIsExample(e.target.checked))}
        />
        <label className="form-check-label" htmlFor="example-toggle">
          Example
        </label>
      </div>

      <Heading title="Solution Code" id="solution-code" />
      <textarea
        rows={5}
        cols={80}
        className="form-control"
        value={model.solutionCode}
        onChange={(e: any) => dispatch(ICActions.editSolutionCode(e.target.value))} />

      <Hints
        projectSlug={props.projectSlug}
        hints={model.authoring.parts[0].hints}
        editMode={props.editMode}
        onAddHint={() => dispatch(ICActions.addHint())}
        onEditHint={(id, content) => dispatch(ICActions.editHint(id, content))}
        onRemoveHint={id => dispatch(ICActions.removeHint(id))} />
    </React.Fragment>
  );
};

export class ImageCodingAuthoring extends AuthoringElement<ImageCodingModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<ImageCodingModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <ImageCoding {...props} />
        <ModalDisplay/>
      </Provider>,
      mountPoint,
    );
  }
}

const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, ImageCodingAuthoring);
