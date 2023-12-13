import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { configureStore } from 'state/store';
import {
  AuthoringElement,
  AuthoringElementProps,
  SectionAuthoringProps,
} from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import * as ActivityTypes from '../types';
import { DirectedDiscussion } from './discussion/DirectedDiscussion';
import { DiscussionParticipationAuthoring } from './discussion/DiscussionParticipationAuthoring';
import { MockDiscussionDeliveryProvider } from './discussion/MockDiscussionDeliveryProvider';
import { DirectedDiscussionActivitySchema } from './schema';

const store = configureStore();

const DirectedDiscussionAuthoringInternal: React.FC<SectionAuthoringProps> = ({
  activityId,
  sectionSlug,
}) => {
  const { dispatch, model, editMode, projectSlug } =
    useAuthoringElementContext<DirectedDiscussionActivitySchema>();

  const displayDiscussion =
    !editMode && activityId && activityId > 0 && sectionSlug && sectionSlug.length > 0;

  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          {displayDiscussion || <Stem />}
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Participation">
          <DiscussionParticipationAuthoring />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <Hints partId={model.authoring.parts[0].id} />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Dynamic Variables">
          <VariableEditorOrNot
            editMode={editMode}
            model={model}
            onEdit={(t) => dispatch(VariableActions.onUpdateTransformations(t))}
          />
        </TabbedNavigation.Tab>
      </TabbedNavigation.Tabs>
      {displayDiscussion && (
        <>
          <hr />
          <MockDiscussionDeliveryProvider
            activityId={activityId}
            model={model}
            projectSlug={projectSlug}
            sectionSlug={sectionSlug}
          >
            <DirectedDiscussion model={model} sectionSlug={sectionSlug} resourceId={activityId} />
          </MockDiscussionDeliveryProvider>
        </>
      )}
    </>
  );
};

type DirectedDiscussionAuthoringProps = AuthoringElementProps<DirectedDiscussionActivitySchema> &
  SectionAuthoringProps;

export class DirectedDiscussionAuthoring extends AuthoringElement<DirectedDiscussionActivitySchema> {
  migrateModelVersion(model: any): DirectedDiscussionActivitySchema {
    return model;
  }

  render(mountPoint: HTMLDivElement, props: DirectedDiscussionAuthoringProps) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <DirectedDiscussionAuthoringInternal
            activityId={props.activityId}
            sectionSlug={props.sectionSlug}
          />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, DirectedDiscussionAuthoring);
