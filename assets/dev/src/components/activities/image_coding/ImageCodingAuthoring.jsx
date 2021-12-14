import { Hints as HintsAuthoring } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { MIMETYPE_FILTERS } from 'components/media/manager/MediaManager';
import { CloseButton } from 'components/misc/CloseButton';
import { Heading } from 'components/misc/Heading';
import { image } from 'data/content/model/elements/factories';
import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import guid from 'utils/guid';
import { AuthoringElement, AuthoringElementProvider, useAuthoringElementContext, } from '../AuthoringElement';
import { ICActions } from './actions';
import { Feedback } from './sections/Feedback';
import { ImageCodeEditor } from './sections/ImageCodeEditor';
import { lastPart } from './utils';
const ImageCoding = (props) => {
    const { dispatch, model, onRequestMedia } = useAuthoringElementContext();
    const { projectSlug } = props;
    const sharedProps = {
        model: props.model,
        editMode: props.editMode,
        projectSlug,
        onRequestMedia,
    };
    function selectImage(_projectSlug, _model) {
        return new Promise((resolve, reject) => {
            const request = {
                type: 'MediaItemRequest',
                mimeTypes: MIMETYPE_FILTERS.IMAGE,
            };
            if (props.onRequestMedia) {
                props.onRequestMedia(request).then((r) => {
                    if (r === false) {
                        reject('error');
                    }
                    else {
                        resolve(r);
                    }
                });
            }
        });
    }
    function selectSpreadsheet(_projectSlug, _model) {
        return new Promise((resolve, reject) => {
            const request = {
                type: 'MediaItemRequest',
                mimeTypes: MIMETYPE_FILTERS.CSV,
            };
            if (props.onRequestMedia) {
                props.onRequestMedia(request).then((r) => {
                    if (r === false) {
                        reject('error');
                    }
                    else {
                        resolve({
                            type: 'img',
                            src: r,
                            id: guid(),
                            children: [],
                        });
                    }
                });
            }
        });
    }
    const addImage = (_e) => {
        selectImage(projectSlug, image()).then((url) => {
            dispatch(ICActions.addResourceURL(url));
        });
    };
    const addSpreadsheet = (_e) => {
        selectSpreadsheet(projectSlug, image()).then((img) => {
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
        return (<div>
        <Heading title="Solution" id="solution-code"/>

        <p>Image problems: Solution Code {!usesImage() ? '-- add image to enable' : ''}</p>
        <ImageCodeEditor disabled={!usesImage()} value={model.solutionCode} onChange={(newValue) => dispatch(ICActions.editSolutionCode(newValue))}/>
        <br />
        <p>
          Tolerance:&nbsp;
          <input type="number" value={model.tolerance} disabled={!usesImage()} onChange={(e) => dispatch(ICActions.editTolerance(e.target.value))}/>
          &nbsp;(Average per-pixel error allowed.)
        </p>

        <p>
          Text output problems:
          <br />
          Regex:&nbsp;
          <input type="text" value={model.regex} disabled={usesImage()} onChange={(e) => dispatch(ICActions.editRegex(e.target.value))}/>
          &nbsp;Pattern for correct text output
        </p>
      </div>);
    };
    return (<React.Fragment>
      <Stem />

      <Heading title="Resources" id="images"/>
      <div>
        <ul className="list-group">
          {model.resourceURLs.map((url, i) => (<li className="list-group-item" key={i}>
              {lastPart(url)}
              <CloseButton className="pl-3 pr-1" editMode={props.editMode} onClick={() => dispatch(ICActions.removeResourceURL(url))}/>
            </li>))}
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

      <Heading title="Starter Code" id="starter-code"/>
      <ImageCodeEditor disabled={false} value={model.starterCode} onChange={(newValue) => dispatch(ICActions.editStarterCode(newValue))}/>
      <br />

      <div className="form-check mb-2">
        <input className="form-check-input" type="checkbox" id="example-toggle" aria-label="Checkbox for example" checked={model.isExample} onChange={(e) => dispatch(ICActions.editIsExample(e.target.checked))}/>
        <label className="form-check-label" htmlFor="example-toggle">
          <b>Example Only</b>
        </label>
      </div>

      {!model.isExample && (<div>
          {solutionParameters()}

          <HintsAuthoring partId={DEFAULT_PART_ID}/>

          <Feedback {...sharedProps} projectSlug={props.projectSlug} onEditResponse={(score, content) => dispatch(ICActions.editFeedback(score, content))}/>
        </div>)}
    </React.Fragment>);
};
const store = configureStore();
export class ImageCodingAuthoring extends AuthoringElement {
    render(mountPoint, props) {
        ReactDOM.render(<Provider store={store}>
        <AuthoringElementProvider {...props}>
          <ImageCoding {...props}/>
        </AuthoringElementProvider>
      </Provider>, mountPoint);
    }
}
// eslint-disable-next-line
const manifest = require('./manifest.json');
window.customElements.define(manifest.authoring.element, ImageCodingAuthoring);
//# sourceMappingURL=ImageCodingAuthoring.jsx.map