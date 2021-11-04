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
import {ActivityXmlEditor} from "components/activities/oli_embedded/sections/ActivityXmlEditor";
import {OliEmbeddedActions} from "components/activities/oli_embedded/actions";
// @ts-ignore
import FileBrowser, {Icons} from "react-keyed-file-browser";

import guid from "utils/guid";
import {uploadFiles} from "components/media/manager/upload";
const store = configureStore();

const Embedded = (props: AuthoringElementProps<OliEmbeddedModelSchema>) => {
  const { dispatch, model, onRequestMedia } = useAuthoringElementContext<OliEmbeddedModelSchema>();
  const [files, setFiles] = useState([
    {
      key: 'photos/animals/cat in a hat.png',
      // modified: +Moment().subtract(1, 'hours'),
      size: 1.5 * 1024 * 1024,
    },
    {
      key: 'photos/animals/kitten_ball.png',
      // modified: +Moment().subtract(3, 'days'),
      size: 545 * 1024,
    },
  ])
  const { projectSlug } = props;

  const onFileUpload = (files: FileList) => {

    // get a list of the files to upload
    const fileList: File[] = [];
    for (let i = 0; i < files.length; i = i + 1) {
      const file = files[i];
      fileList.push(renameFile(file, 'webcontent/'+ file.name));
    }

    uploadFiles(projectSlug, fileList)
      .then((result: any) => {
        console.log(result);
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
      <Heading
        title="Embedded Activity"
        subtitle="Embedded Activity subtitle"
        id="embedded"
      />
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
          // disabled={disabled}
          className="btn btn-primary media-toolbar-item upload"
          onClick={() => onUploadClick(id)}
        >
          <i className="fa fa-upload" /> Upload File
        </button>
      </div>
      <FileBrowser
        files={files}
        icons={{
          File: <i className="fa fa-file" />,
          Image: <i className="fa fa-file-image" />,
          Folder: <i className="fa fa-folder" />,
          FolderOpen: <i className="fa fa-folder-open" />
        }}
      />
      {/*  theme: 'vs',*/}
      {/*}}/>*/}
      {/*<div>*/}
      {/*  <input*/}
      {/*    id={id}*/}
      {/*    style={{ display: 'none' }}*/}
      {/*    disabled={disabled}*/}
      {/*    accept={mimeFilter && `${mimeFilter}`}*/}
      {/*    multiple*/}
      {/*    onChange={({ target: { files } }) => onFileUpload(files as FileList)}*/}
      {/*    type="file"*/}
      {/*  />*/}
      {/*</div>*/}
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