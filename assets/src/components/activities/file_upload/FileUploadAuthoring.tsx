import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { Manifest } from 'components/activities/types';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { FileSpecConfiguration } from './FileSpecConfiguration';
import { FileUploadActions } from './actions';
import { FileUploadSchema, FileSpec } from './schema';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';

const store = configureStore();

const FileUpload = () => {
  const { dispatch, model, editMode } = useAuthoringElementContext<FileUploadSchema>();

  const onEditFileSpec = (fileSpec: FileSpec) => dispatch(FileUploadActions.editFileSpec(fileSpec));

  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <div className="d-flex flex-column flex-md-row mb-2">
            <Stem />
          </div>
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Allowed Files">
          <FileSpecConfiguration
            editMode={editMode}
            fileSpec={model.fileSpec}
            onEdit={onEditFileSpec}
          />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <Hints partId={DEFAULT_PART_ID} />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Dynamic Variables">
          <VariableEditorOrNot
            editMode={editMode}
            model={model}
            onEdit={(t) => dispatch(VariableActions.onUpdateTransformations(t))}
          />
        </TabbedNavigation.Tab>
      </TabbedNavigation.Tabs>
    </>
  );
};

export class FileUploadAuthoring extends AuthoringElement<FileUploadSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<FileUploadSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <FileUpload />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.authoring.element, FileUploadAuthoring);
