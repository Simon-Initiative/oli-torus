import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { ImageCodingModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { ICActions } from './actions';
import { Provider } from 'react-redux';
import { Heading } from 'components/misc/Heading';
import { MIMETYPE_FILTERS } from 'components/media/manager/MediaManager';
import * as ContentModel from 'data/content/model';
import { Feedback } from './sections/Feedback';
import { lastPart } from './utils';
import { CloseButton } from 'components/misc/CloseButton';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { ImageCodeEditor } from './sections/ImageCodeEditor';
import guid from 'utils/guid';
import { MediaItemRequest } from '../types';
import { configureStore } from 'state/store';

const ImageCoding = (props: AuthoringElementProps<ImageCodingModelSchema>) => {
  const { dispatch, model, onRequestMedia } = useAuthoringElementContext<ImageCodingModelSchema>();

  const { projectSlug } = props;

  const sharedProps = {
    model: props.model,
    editMode: props.editMode,
    projectSlug,
    onRequestMedia,
  };

  function selectImage(projectSlug: string, model: ContentModel.Image): Promise<string> {
    return new Promise((resolve, reject) => {
      const request = {
        type: 'MediaItemRequest',
        mimeTypes: MIMETYPE_FILTERS.IMAGE,
      } as MediaItemRequest;
      if (props.onRequestMedia) {
        props.onRequestMedia(request).then((r) => {
          console.log(r);
          if (r === false) {
            reject('error');
          } else {
            console.log('resovl');
            resolve(r as string);
          }
        });
      }
    });
  }

  function selectSpreadsheet(
    projectSlug: string,
    model: ContentModel.Image,
  ): Promise<ContentModel.Image> {
    return new Promise((resolve, reject) => {
      const request = {
        type: 'MediaItemRequest',
        mimeTypes: MIMETYPE_FILTERS.CSV,
      } as MediaItemRequest;
      if (props.onRequestMedia) {
        props.onRequestMedia(request).then((r) => {
          if (r === false) {
            reject('error');
          } else {
            resolve({
              type: 'img',
              src: r as string,
              id: guid(),
              children: [],
            });
          }
        });
      }
    });
  }

  const addImage = (e: any) => {
    selectImage(projectSlug, ContentModel.image()).then((url: string) => {
      dispatch(ICActions.addResourceURL(url));
    });
  };

  const addSpreadsheet = (e: any) => {
    selectSpreadsheet(projectSlug, ContentModel.image()).then((img) => {
      dispatch(ICActions.addResourceURL(img.src));
    });
  };

  const usesImage = () => {
    return model.resourceURLs.some((url) => !url.endsWith('csv'));
  };

  const usesSpreadsheet = () => {
    return model.resourceURLs.some((url) => url.endsWith('csv'));
  };

  const solutionParameters = () => {
    return (
      <div>
        <Heading title="Solution" id="solution-code" />

        <p>Image problems: Solution Code {!usesImage() ? '-- add image to enable' : ''}</p>
        <ImageCodeEditor
          disabled={!usesImage()}
          value={model.solutionCode}
          onChange={(newValue: string) => dispatch(ICActions.editSolutionCode(newValue))}
        />
        <br />
        <p>
          Tolerance:&nbsp;
          <input
            type="number"
            value={model.tolerance}
            disabled={!usesImage()}
            onChange={(e: any) => dispatch(ICActions.editTolerance(e.target.value))}
          />
          &nbsp;(Average per-pixel error allowed.)
        </p>

        <p>
          Text output problems:
          <br />
          Regex:&nbsp;
          <input
            type="text"
            value={model.regex}
            disabled={usesImage()}
            onChange={(e: any) => dispatch(ICActions.editRegex(e.target.value))}
          />
          &nbsp;Pattern for correct text output
        </p>
      </div>
    );
  };

  return (
    <React.Fragment>
      <Stem />

      <Heading title="Resources" id="images" />
      <div>
        <ul className="list-group">
          {model.resourceURLs.map((url, i) => (
            <li className="list-group-item" key={i}>
              {lastPart(url)}
              <CloseButton
                className="pl-3 pr-1"
                editMode={props.editMode}
                onClick={() => dispatch(ICActions.removeResourceURL(url))}
              />
            </li>
          ))}
        </ul>
        <button className="btn btn-primary mt-2" onClick={addImage} disabled={usesSpreadsheet()}>
          Add Image...
        </button>
        &nbsp;&nbsp;&nbsp;
        <button className="btn btn-primary mt-2" onClick={addSpreadsheet} disabled={usesImage()}>
          Add Spreadsheet...
        </button>
      </div>
      <br />

      <Heading title="Starter Code" id="starter-code" />
      <ImageCodeEditor
        disabled={false}
        value={model.starterCode}
        onChange={(newValue: string) => dispatch(ICActions.editStarterCode(newValue))}
      />
      <br />

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

      {!model.isExample && (
        <div>
          {solutionParameters()}

          <Hints hintsPath="$.authoring.parts[0].hints" />

          <Feedback
            {...sharedProps}
            projectSlug={props.projectSlug}
            onEditResponse={(score, content) => dispatch(ICActions.editFeedback(score, content))}
          />
        </div>
      )}
    </React.Fragment>
  );
};

const store = configureStore();

export class ImageCodingAuthoring extends AuthoringElement<ImageCodingModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<ImageCodingModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <ImageCoding {...props} />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, ImageCodingAuthoring);
