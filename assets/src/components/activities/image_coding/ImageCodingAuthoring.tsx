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
import ModalSelection, { sizes } from 'components/modal/ModalSelection';
import { modalActions } from 'actions/modal';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import { MediaManager } from 'components/media/manager/MediaManager.controller';
import { MediaItem } from 'types/media';
import * as ContentModel from 'data/content/model';
import { Feedback } from './sections/Feedback';
import { lastPart } from './utils';
import { CloseButton } from 'components/misc/CloseButton';

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

  // Modal image selection
  const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
  const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

  function selectImage(projectSlug: string,
    model: ContentModel.Image): Promise<ContentModel.Image> {

    return new Promise((resolve, reject) => {

      const selected = { img: null };

      const mediaLibrary =
          <ModalSelection title="Select an image" size={sizes.extraLarge}
            onInsert={() => { dismiss(); resolve(selected.img as any); }}
            onCancel={() => dismiss()}
            disableInsert={true}
          >
            <MediaManager
              projectSlug={projectSlug}
              onEdit={() => { }}
              mimeFilter={MIMETYPE_FILTERS.IMAGE}
              selectionType={SELECTION_TYPES.SINGLE}
              initialSelectionPaths={model.src ? [model.src] : [selected.img as any]}
              onSelectionChange={(images: MediaItem[]) => {
                (selected as any).img = ContentModel.image(images[0].url);
              }} />
          </ModalSelection>;

      display(mediaLibrary);
    });
  }

  function selectSpreadsheet(projectSlug: string,
    model: ContentModel.Image): Promise<ContentModel.Image> {

    return new Promise((resolve, reject) => {

      const selected = { file: null };

      const mediaLibrary =
          <ModalSelection title="Select a csv file" size={sizes.extraLarge}
            onInsert={() => { dismiss(); resolve(selected.file as any); }}
            onCancel={() => dismiss()}
            disableInsert={true}
          >
            <MediaManager
              projectSlug={projectSlug}
              onEdit={() => { }}
              mimeFilter={MIMETYPE_FILTERS.CSV}
              selectionType={SELECTION_TYPES.SINGLE}
              initialSelectionPaths={model.src ? [model.src] : [selected.file as any]}
              onSelectionChange={(files: MediaItem[]) => {
                (selected as any).file = ContentModel.image(files[0].url);
              }} />
          </ModalSelection>;

      display(mediaLibrary);
    });
  }

  const addImage = (e : any) => {
    selectImage(projectSlug, ContentModel.image()).then((img) => {
      dispatch(ICActions.addResourceURL(img.src));
    });
  };

  const addSpreadsheet = (e : any) => {
    selectSpreadsheet(projectSlug, ContentModel.image()).then((img) => {
      dispatch(ICActions.addResourceURL(img.src));
    });
  };

  const usesImage = () => {
    return model.resourceURLs.some(url => !url.endsWith('csv'));
  };

  const usesSpreadsheet = () => {
    return model.resourceURLs.some(url => url.endsWith('csv'));
  };

  const solutionParameters = () => {
    return (
      <div>
        <Heading title="Solution" id="solution-code" />

        <p>Image problems: Solution Code {!usesImage() ? '-- add image to enable' : ''}</p>
        <textarea
          disabled={!usesImage()}
          rows={5}
          cols={80}
          className="form-control"
          value={model.solutionCode}
          onChange={(e: any) => dispatch(ICActions.editSolutionCode(e.target.value))} />
        <br/>
        <p>Tolerance:&nbsp;
          <input type="number" value={model.tolerance}  disabled={!usesImage()}
                onChange={(e: any) => dispatch(ICActions.editTolerance(e.target.value))}/>
          &nbsp;(Average per-pixel error allowed.)
        </p>

        <p>Text output problems:<br/>Regex:&nbsp;
          <input type="text" value={model.regex} disabled={usesImage()}
                onChange={(e: any) => dispatch(ICActions.editRegex(e.target.value))}/>
          &nbsp;Pattern for correct text output
        </p>
      </div>
    );
  };

  return (
    <React.Fragment>
      <Stem
        projectSlug={props.projectSlug}
        editMode={props.editMode}
        stem={model.stem}
        onEditStem={content => dispatch(ICActions.editStem(content))} />

      <Heading title="Resources" id="images" />
        <div>
          <ul className="list-group">
            {model.resourceURLs.map((url, i) =>
              <li className="list-group-item" key={i}>
                {lastPart(url)}
                <CloseButton
                  className="pl-3 pr-1"
                  editMode={props.editMode}
                  onClick={() => dispatch(ICActions.removeResourceURL(url))}/>
              </li>)}
          </ul>
          <button
            className="btn btn-primary mt-2" onClick={addImage} disabled={usesSpreadsheet()}>
            Add Image...
          </button>
          &nbsp;&nbsp;&nbsp;
          <button
            className="btn btn-primary mt-2" onClick={addSpreadsheet} disabled={usesImage()}>
            Add Spreadsheet...
          </button>
        </div>
      <br/>

      <Heading title="Starter Code" id="starter-code" />
      <textarea
        rows={5}
        cols={80}
        className="form-control"
        value={model.starterCode}
        onChange={(e: any) => dispatch(ICActions.editStarterCode(e.target.value))} />
        <br/>

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
          <b>Example Only</b>
        </label>
      </div>

      {! model.isExample &&

        <div>

          {solutionParameters()}

          <Hints
            projectSlug={props.projectSlug}
            hints={model.authoring.parts[0].hints}
            editMode={props.editMode}
            onAddHint={() => dispatch(ICActions.addHint())}
            onEditHint={(id, content) => dispatch(ICActions.editHint(id, content))}
            onRemoveHint={id => dispatch(ICActions.removeHint(id))} />

          <Feedback {...sharedProps}
            projectSlug={props.projectSlug}
            onEditResponse={(score, content) => dispatch(ICActions.editFeedback(score, content))} />
        </div>
      }

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
