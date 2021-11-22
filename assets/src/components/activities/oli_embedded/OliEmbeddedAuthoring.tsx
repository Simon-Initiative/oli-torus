import {configureStore} from "state/store";
import React, {useEffect, useState} from "react";
import {Heading} from "components/misc/Heading";
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider, useAuthoringElementContext
} from "components/activities/AuthoringElement";
import {OliEmbeddedModelSchema} from "components/activities/oli_embedded/schema";
import ReactDOM from "react-dom";
import {Provider} from "react-redux";
import * as ActivityTypes from "components/activities/types";
import {OliEmbeddedActions} from "components/activities/oli_embedded/actions";

import guid from "utils/guid";
import {uploadFiles} from "components/media/manager/upload";
import {CloseButton} from "components/misc/CloseButton";
import * as ContentModel from "data/content/model";
import {MediaItemRequest} from "components/activities/types";
import {lastPart} from "components/activities/oli_embedded/utils";
import {ActivityXmlEditor} from "components/common/ActivityXmlEditor";
const store = configureStore();

const Embedded = (props: AuthoringElementProps<OliEmbeddedModelSchema>) => {
  const { dispatch, model, onRequestMedia } = useAuthoringElementContext<OliEmbeddedModelSchema>();

  const { projectSlug } = props;

  function select(_projectSlug: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const request = {
        type: 'MediaItemRequest'
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

  const addFile = (e: any) => {
    select(projectSlug).then((url: string) => {
      dispatch(OliEmbeddedActions.addResourceURL(url));
    });
  };

  const onFileUpload = (files: FileList) => {
    // get a list of the files to upload
    const fileList: File[] = [];
    for (let i = 0; i < files.length; i = i + 1) {
      const file = files[i];
      fileList.push(renameFile(file, 'webcontent/'+ model.resourceBase +'/' + file.name));
    }

    uploadFiles(projectSlug, fileList)
      .then((result: any) => {
        result.forEach((i: any) => {
          OliEmbeddedActions.addResourceURL(i.url);
        })
        console.log(JSON.stringify(result));
      }).catch((reason: any) => {
      console.log(JSON.stringify(reason));
    });

  }

  const renameFile = (originalFile: any, newName: string) => {
    return new File([originalFile], newName, {
      type: originalFile.type,
      lastModified: originalFile.lastModified,
    });
  }

  const onUploadClick = (id: string) => {
    (window as any).$('#' + id).trigger('click');
  }

  useEffect(() => {
     // console.log(JSON.stringify(model));
  }, []);

  const id = guid();
  return (
    <>
      <ActivityXmlEditor
        value={model.modelXml} disabled={false}
        onChange={(newValue: string) => dispatch(OliEmbeddedActions.editActivityXml(newValue))}/>
      <div className="m-2">
        <input
          id={id}
          style={{ display: 'none' }}
          // accept={mimeFilter && `${mimeFilter}`}
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
        <button
          className="btn btn-primary media-toolbar-item upload"
          onClick={() => addFile(id)}
        >
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
      <div className="card" >
        <div className="card-body">
          <div className="card-title">Parts</div>
      <div className="d-flex flex-row align-items-baseline">
        <div className="flex-grow-1">
          <div className="d-flex justify-content-start m-2">
            <div className="mr-2 p-2">&nbsp;</div>
            <div className="mr-2 p-2">Id</div>
            <div className="mr-2 p-2">Scoring Strategy</div>
          </div>
        {model.authoring.parts.map((part, i) => (
            <div className="d-flex justify-content-start m-2" key={i}>
              <div className="mr-2 p-2">Part {i+1}</div>
              <div className="d-flex justify-content-start bg-white p-2">
              <div className="mr-3">{part.id}</div>
              <div>
                <select onChange={handleValueChange} className="custom-select custom-select-sm">
                  {value?.allowedValues?.map((item: any) => {
                    return (
                      <option key={item} value={item} selected={internalValue === item}>
                        {item}
                      </option>
                    );
                  })}
                </select>
              </div>
              </div>
            </div>
        ))}
      </div>
        </div>
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
          <Embedded {...props}/>
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, OliEmbeddedAuthoring);