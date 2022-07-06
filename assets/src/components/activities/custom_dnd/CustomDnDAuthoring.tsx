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
import { WrappedMonaco } from '../common/variables/WrappedMonaco';
import { CustomDnDActions } from './actions';
import { CustomDnDSchema } from './schema';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';

const store = configureStore();

const CustomDnd = () => {
  const { dispatch, model, editMode } = useAuthoringElementContext<CustomDnDSchema>();

  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <div className="d-flex flex-column flex-md-row mb-2">
            <Stem />
          </div>
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
        <TabbedNavigation.Tab label="CSS">
          <WrappedMonaco
            model={model.layoutStyles}
            editMode={editMode}
            language="CSS"
            onEdit={(s) => dispatch(CustomDnDActions.editLayoutStyles(s))}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Target Area">
          <WrappedMonaco
            model={model.targetArea}
            editMode={editMode}
            language="HTML"
            onEdit={(s) => dispatch(CustomDnDActions.editTargetArea(s))}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Initiators">
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
