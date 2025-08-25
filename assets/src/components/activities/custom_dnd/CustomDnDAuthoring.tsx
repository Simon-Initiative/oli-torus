import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { Manifest } from 'components/activities/types';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { WrappedMonaco } from '../common/variables/WrappedMonaco';
import { StudentResponses } from '../common/responses/StudentResponses';
import { AnswerKey } from './AnswerKey';
import { HintsEditor } from './HintsEditor';
import { PartManager } from './PartManager';
import { CustomDnDActions } from './actions';
import { CustomDnDSchema } from './schema';

const store = configureStore();

const CustomDnd = () => {
  const { dispatch, model, editMode, mode } = useAuthoringElementContext<CustomDnDSchema>();
  const [currentPart, setCurrentPart] = React.useState<string>(model.authoring.parts[0].id);
  const isInstructorPreview = mode === 'instructor_preview';

  return (
    <>
      <div className="mt-3 mb-3" />
      <Stem />
      <div className="mt-3 mb-3" />
      <PartManager
        model={model}
        editMode={editMode}
        currentPartId={currentPart}
        onSelectPart={(partId) => setCurrentPart(partId)}
        onAddPart={() => dispatch(CustomDnDActions.addPart())}
        onRemovePart={(id) => {
          if (model.authoring.parts.length > 1) {
            const remainingParts = model.authoring.parts.filter((p) => p.id !== id);
            setCurrentPart(remainingParts[0].id);
            dispatch(CustomDnDActions.removePart(id));
          }
        }}
        onEditPart={(old, newId) => {
          dispatch(CustomDnDActions.editPart(old, newId));
          setCurrentPart(newId);
        }}
      />
      <div className="mb-3" />
      <TabbedNavigation.Tabs>
        {mode === 'instructor_preview' && (
          <TabbedNavigation.Tab label="Student Responses">
            <StudentResponses model={model} />
          </TabbedNavigation.Tab>
        )}

        <TabbedNavigation.Tab label={`Answer Key (${currentPart})`}>
          <AnswerKey partId={currentPart} />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label={`Hints (${currentPart})`}>
          <HintsEditor partId={currentPart} />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="CSS">
          <div className="alert alert-info" role="alert">
            Define custom CSS styles here. Do not include the outer <code>&lt;style&gt;</code>{' '}
            element. Background image URLs must contain the full URL to the image.
          </div>
          <WrappedMonaco
            model={model.layoutStyles}
            editMode={editMode}
            language="CSS"
            onEdit={(s) => dispatch(CustomDnDActions.editLayoutStyles(s))}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Target Area">
          <div className="alert alert-info" role="alert">
            Every target area must have a corresponding <code>&lt;div&gt;</code> element whose{' '}
            <code>input_ref</code> attribute is set to that target identifier. Each of these{' '}
            <code>&lt;div&gt;</code> elements must also have <code>target</code> set as a CSS class
            name.
          </div>
          <WrappedMonaco
            model={model.targetArea}
            editMode={editMode}
            language="HTML"
            onEdit={(s) => dispatch(CustomDnDActions.editTargetArea(s))}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Initiators">
          <div className="alert alert-info" role="alert">
            For each possible initiator (the things students will drag) define a{' '}
            <code>&lt;div&gt;</code> element whose <code>input_val</code> attribute is set to that
            initiator identifier. Each of these <code>&lt;div&gt;</code> elements must also have{' '}
            <code>initiator</code> set as a CSS class name.
          </div>
          <WrappedMonaco
            model={model.initiators}
            editMode={editMode}
            language="HTML"
            onEdit={(s) => dispatch(CustomDnDActions.editInitiators(s))}
          />
        </TabbedNavigation.Tab>

      </TabbedNavigation.Tabs>
    </>
  );
};

export class CustomDnDAuthoring extends AuthoringElement<CustomDnDSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<CustomDnDSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <CustomDnd />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.authoring.element, CustomDnDAuthoring);
