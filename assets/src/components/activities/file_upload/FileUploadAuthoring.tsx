import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { Manifest } from 'components/activities/types';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { Explanation } from '../common/explanation/ExplanationAuthoring';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import { StudentResponses } from '../common/responses/StudentResponses';
import { FileSpecConfiguration } from './FileSpecConfiguration';
import { FileUploadActions } from './actions';
import { FileSpec, FileUploadSchema } from './schema';

const store = configureStore();

const ControlledTabs: React.FC<{ isInstructorPreview: boolean; children: React.ReactNode }> = ({ 
  isInstructorPreview, 
  children 
}) => {
  const [activeTab, setActiveTab] = React.useState<number>(0);

  // Force the first visible tab to be active when the mode changes
  React.useEffect(() => {
    setActiveTab(0);
  }, [isInstructorPreview]);

  const validChildren = React.Children.toArray(children).filter(
    (child): child is React.ReactElement => React.isValidElement(child)
  );

  return (
    <>
      <ul className="nav nav-tabs my-2 flex justify-between" role="tablist">
        {validChildren.map((child, index) => (
          <li key={'tab-' + index} className="nav-item" role="presentation">
            <button
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setActiveTab(index);
              }}
              className={'text-primary nav-link px-3' + (index === activeTab ? ' active' : '')}
              data-bs-toggle="tab"
              role="tab"
              aria-controls={'tab-' + index}
              aria-selected={index === activeTab}
            >
              {child.props.label}
            </button>
          </li>
        ))}
      </ul>
      <div className="tab-content">
        {validChildren.map((child, index) => (
          <div
            key={'tab-content-' + index}
            className={'tab-pane' + (index === activeTab ? ' show active' : '')}
            role="tabpanel"
            aria-labelledby={'tab-' + index}
          >
            {child.props.children}
          </div>
        ))}
      </div>
    </>
  );
};

const FileUpload = () => {
  const { dispatch, model, editMode, mode } = useAuthoringElementContext<FileUploadSchema>();
  const isInstructorPreview = mode === 'instructor_preview';

  const onEditFileSpec = (fileSpec: FileSpec) => dispatch(FileUploadActions.editFileSpec(fileSpec));

  return (
    <>
      <ControlledTabs isInstructorPreview={isInstructorPreview}>
        {mode === 'instructor_preview' && (
          <TabbedNavigation.Tab label="Student Responses">
            <StudentResponses model={model} />
          </TabbedNavigation.Tab>
        )}

        {!isInstructorPreview && (
          <TabbedNavigation.Tab label="Question">
            <div className="d-flex flex-column flex-md-row mb-2">
              <Stem />
            </div>
          </TabbedNavigation.Tab>
        )}
        <TabbedNavigation.Tab label="Allowed Files">
          <FileSpecConfiguration
            editMode={editMode}
            fileSpec={model.fileSpec}
            onEdit={onEditFileSpec}
          />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <Hints partId={model.authoring.parts[0].id} />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Explanation">
          <Explanation partId={model.authoring.parts[0].id} />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Dynamic Variables">
          <VariableEditorOrNot
            editMode={editMode}
            mode={mode}
            model={model}
            onEdit={(t) => dispatch(VariableActions.onUpdateTransformations(t))}
          />
        </TabbedNavigation.Tab>

      </ControlledTabs>
    <>
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
