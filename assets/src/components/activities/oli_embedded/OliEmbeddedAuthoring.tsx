import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { AuthoringElement, AuthoringElementProps } from 'components/activities/AuthoringElement';
import { OliEmbeddedActions } from 'components/activities/oli_embedded/actions';
import { OliEmbeddedModelSchema } from 'components/activities/oli_embedded/schema';
import { lastPart } from 'components/activities/oli_embedded/utils';
import * as ActivityTypes from 'components/activities/types';
import { MediaItemRequest, ScoringStrategy } from 'components/activities/types';
import { uploadFiles } from 'components/media/manager/upload';
import { CloseButton } from 'components/misc/CloseButton';
import { Modal } from 'components/modal/Modal';
import { configureStore } from 'state/store';
import guid from 'utils/guid';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { WrappedMonaco } from '../common/variables/WrappedMonaco';

const store = configureStore();

const Embedded = (props: AuthoringElementProps<OliEmbeddedModelSchema>) => {
  const { dispatch, model } = useAuthoringElementContext<OliEmbeddedModelSchema>();

  const { projectSlug } = props;

  function select(projectSlug: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const request = {
        type: 'MediaItemRequest',
      } as MediaItemRequest;
      if (props.onRequestMedia) {
        props.onRequestMedia(request).then((r) => {
          if (r === false) {
            reject('error');
          } else {
            resolve(r as string);
          }
        });
      } else {
        reject('error');
      }
    });
  }

  const addFile = () => {
    select(projectSlug).then((url: string) => {
      dispatch(OliEmbeddedActions.addResourceURL(url));
    });
  };

  const display = (c: any, id: string) => {
    let element = document.querySelector('#' + id);
    if (!element) {
      element = document.createElement('div');
      element.id = id;
      document.body.appendChild(element);
    }
    ReactDOM.render(c, element);
  };

  const onFileUpload = (files: FileList) => {
    // get a list of the files to upload
    const fileList: File[] = [];
    for (let i = 0; i < files.length; i = i + 1) {
      const file = files[i];
      fileList.push(file);
    }

    uploadFiles(projectSlug, fileList)
      .then((result: any) => {
        result.forEach((i: any) => {
          dispatch(OliEmbeddedActions.addResourceURL(i.url));
        });
      })
      .catch((reason: any) => {
        const id = 'upload_error';
        display(errorModal(reason.message, id), id);
      });
  };

  const onUploadClick = (id: string) => {
    (window as any).$('#' + id).trigger('click');
  };

  const handleScoringChange = (partId: string, key: string) => {
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-ignore
    const scoring: ScoringStrategy = ScoringStrategy[key];
    dispatch(OliEmbeddedActions.updatePartScoringStrategy(partId, scoring));
  };

  const removePart = (partId: string) => {
    dispatch(OliEmbeddedActions.removePart(partId));
  };

  const addNewPart = () => {
    dispatch(OliEmbeddedActions.addNewPart());
  };

  const id = guid();

  const dismiss = (id: string) => {
    const element = document.querySelector('#' + id);
    if (element) {
      ReactDOM.unmountComponentAtNode(element);
    }
  };

  const errorModal = (error: string, id: string) => {
    const footer = (
      <>
        <button
          type="button"
          className="btn btn-primary"
          onClick={() => {
            dismiss(id);
          }}
        >
          Ok
        </button>
      </>
    );

    return (
      <Modal
        title="File Upload"
        footer={footer}
        onCancel={() => {
          dismiss(id);
        }}
      >
        <div className="alert alert-warning">{error}</div>
      </Modal>
    );
  };

  return (
    <>
      <WrappedMonaco
        model={model.modelXml}
        editMode={true}
        language="xml"
        onEdit={(s: string) => dispatch(OliEmbeddedActions.editActivityXml(s))}
      />

      <div className="m-2">
        <input
          id={id}
          style={{ display: 'none' }}
          multiple
          onChange={({ target: { files } }) => onFileUpload(files as FileList)}
          type="file"
        />
        <button
          className="btn btn-primary media-toolbar-item upload"
          onClick={() => onUploadClick(id)}
        >
          <i className="fa fa-upload" /> Upload File
        </button>
        &nbsp;&nbsp;&nbsp;
        <button className="btn btn-primary media-toolbar-item upload" onClick={() => addFile()}>
          Media Library
        </button>
      </div>
      <ul className="list-group">
        {model.resourceURLs.map((url, i) => (
          <li className="list-group-item" key={i}>
            {lastPart(url)}
            <CloseButton
              className="pl-3 pr-1"
              editMode={props.editMode}
              onClick={() => dispatch(OliEmbeddedActions.removeResourceURL(url))}
            />
          </li>
        ))}
      </ul>
      <div className="card">
        <div className="card-body">
          <div className="card-title">Parts</div>

          <div className="container">
            <div className="row mb-2 text-center">
              <div className="col sm:col-span-2">&nbsp;</div>
              <div className="col lg:col-span-2">Id</div>
              <div className="col lg:col-span-2">Scoring</div>
            </div>
            {model.authoring.parts.map((part, i) => (
              <div className="row mb-2" key={i}>
                <div className="col sm:col-span-2">Part {i + 1}</div>
                <div className="col lg:col-span-3">{part.id}</div>
                <div className="col lg:col-span-2">
                  <select
                    onChange={(e) => handleScoringChange(part.id, e.target.value)}
                    className="custom-select custom-select-sm"
                  >
                    {Object.keys(ScoringStrategy).map((key: string) => (
                      <option key={key} value={key} selected={part.scoringStrategy === key}>
                        {
                          // eslint-disable-next-line @typescript-eslint/ban-ts-comment
                          // @ts-ignore
                          ScoringStrategy[key]
                        }
                      </option>
                    ))}
                  </select>
                </div>
                <div className="col-md-auto">
                  <button
                    onClick={() => removePart(part.id)}
                    type="button"
                    className="close"
                    data-dismiss="alert"
                    aria-label="Close"
                  >
                    <i className="fa-solid fa-xmark fa-xl"></i>
                  </button>
                </div>
              </div>
            ))}
          </div>
          <button className="btn btn-primary" onClick={() => addNewPart()}>
            Add Part
          </button>
        </div>
      </div>
    </>
  );
};

export class OliEmbeddedAuthoring extends AuthoringElement<OliEmbeddedModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<OliEmbeddedModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <Embedded {...props} />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, OliEmbeddedAuthoring);
