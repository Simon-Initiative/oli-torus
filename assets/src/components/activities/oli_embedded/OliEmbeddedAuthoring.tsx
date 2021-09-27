import {configureStore} from "state/store";
import React from "react";
import {Heading} from "components/misc/Heading";
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider
} from "components/activities/AuthoringElement";
import {OliEmbeddedModelSchema} from "components/activities/oli_embedded/schema";
import ReactDOM from "react-dom";
import {Provider} from "react-redux";
import * as ActivityTypes from "components/activities/types";

const store = configureStore();

const Embedded: React.FC = () => {

  const onFileUpload = (files: FileList) => {


  }

  return (
    <>
      <Heading
        title="Embedded Activity"
        subtitle="Embedded Activity subtitle"
        id="embedded"
      />
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
          <Embedded />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, OliEmbeddedAuthoring);