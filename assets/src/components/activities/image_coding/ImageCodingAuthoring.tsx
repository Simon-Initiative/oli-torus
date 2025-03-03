import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Hints as HintsAuthoring } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { MIMETYPE_FILTERS } from 'components/media/manager/MediaManager';
import { CloseButton } from 'components/misc/CloseButton';
import { Heading } from 'components/misc/Heading';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Model } from 'data/content/model/elements/factories';
import * as ContentModel from 'data/content/model/elements/types';
import { configureStore } from 'state/store';
import guid from 'utils/guid';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { Explanation } from '../common/explanation/ExplanationAuthoring';
import { TriggerAuthoring, TriggerLabel } from '../common/triggers/TriggerAuthoring';
import * as ActivityTypes from '../types';
import { MediaItemRequest } from '../types';
import { ICActions } from './actions';
import { ImageCodingModelSchema } from './schema';
import { Feedback } from './sections/Feedback';
import { ImageCodeEditor } from './sections/ImageCodeEditor';
import { lastPart } from './utils';

const ImageCoding = (props: AuthoringElementProps<ImageCodingModelSchema>) => {
  const { dispatch, model, onRequestMedia, authoringContext } =
    useAuthoringElementContext<ImageCodingModelSchema>();

  const { projectSlug } = props;

  const sharedProps = {
    model: props.model,
    editMode: props.editMode,
    projectSlug,
    onRequestMedia,
  };

  function selectImage(_projectSlug: string, _model: ContentModel.ImageBlock): Promise<string> {
    return new Promise((resolve, reject) => {
      const request = {
        type: 'MediaItemRequest',
        mimeTypes: MIMETYPE_FILTERS.IMAGE,
      } as MediaItemRequest;
      if (props.onRequestMedia) {
        props.onRequestMedia(request).then((r) => {
          if (r === false) {
            reject('error');
          } else {
            resolve(r as string);
          }
        });
      }
    });
  }

  function selectSpreadsheet(
    _projectSlug: string,
    _model: ContentModel.ImageBlock,
  ): Promise<ContentModel.ImageBlock> {
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

  const addImage = (_e: any) => {
    selectImage(projectSlug, Model.image()).then((url: string) => {
      dispatch(ICActions.addResourceURL(url));
    });
  };

  const addSpreadsheet = (_e: any) => {
    selectSpreadsheet(projectSlug, Model.image()).then((img) => {
      img.src && dispatch(ICActions.addResourceURL(img.src));
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
          <TabbedNavigation.Tabs>
            <TabbedNavigation.Tab label="Answer Key">
              {solutionParameters()}
              <Feedback
                {...sharedProps}
                projectSlug={props.projectSlug}
                onChangeTextDirection={(score, textDirection) =>
                  dispatch(ICActions.editFeedbackTextDirection(score, textDirection))
                }
                onEditEditorType={(score, editor) =>
                  dispatch(ICActions.editFeedbackEditorType(score, editor))
                }
                onEditResponse={(score, content) =>
                  dispatch(ICActions.editFeedback(score, content))
                }
              />
            </TabbedNavigation.Tab>
            <TabbedNavigation.Tab label="Hints">
              <HintsAuthoring partId={model.authoring.parts[0].id} />
            </TabbedNavigation.Tab>
            <TabbedNavigation.Tab label="Explanation">
              <Explanation partId={model.authoring.parts[0].id} />
            </TabbedNavigation.Tab>

            {authoringContext.optionalContentTypes.triggers && (
              <TabbedNavigation.Tab label={TriggerLabel()}>
                <TriggerAuthoring partId={model.authoring.parts[0].id} />
              </TabbedNavigation.Tab>
            )}
          </TabbedNavigation.Tabs>
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
