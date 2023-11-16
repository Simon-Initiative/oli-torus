import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Maybe } from 'tsmonad';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { mcV1toV2 } from 'components/activities/multiple_choice/transformations/v2';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import * as ActivityTypes from '../types';
import { DiscussionParticipationAuthoring } from './discussion/DiscussionParticipationAuthoring';
import { DirectedDiscussionActivitySchema } from './schema';

const store = configureStore();

const DirectedDiscussion: React.FC = () => {
  const { dispatch, model, editMode } =
    useAuthoringElementContext<DirectedDiscussionActivitySchema>();

  // const writerContext = defaultWriterContext({
  //   projectSlug: projectSlug,
  // });

  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          {JSON.stringify(model)}
          <Stem />
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

        {/* <ActivitySettings settings={[shuffleAnswerChoiceSetting(model, dispatch)]} /> */}
      </TabbedNavigation.Tabs>
    </>
  );
};

export class DirectedDiscussionAuthoring extends AuthoringElement<DirectedDiscussionActivitySchema> {
  migrateModelVersion(model: any): DirectedDiscussionActivitySchema {
    return Maybe.maybe(model.authoring.version).caseOf({
      just: (_v2) => model,
      nothing: () => mcV1toV2(model),
    });
  }

  render(
    mountPoint: HTMLDivElement,
    props: AuthoringElementProps<DirectedDiscussionActivitySchema>,
  ) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <DirectedDiscussion />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, DirectedDiscussionAuthoring);
