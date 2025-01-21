import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Maybe } from 'tsmonad';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { ResponseChoices } from 'components/activities/ordering/sections/ResponseChoices';
import { TargetedFeedback } from 'components/activities/ordering/sections/TargetedFeedback';
import {
  OrderingSchemaV2,
  orderingV1toV2,
} from 'components/activities/ordering/transformations/v2';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Choices } from 'data/activities/model/choices';
import { findTargetedResponses, getCorrectChoiceIds } from 'data/activities/model/responses';
import { ruleValue } from 'data/activities/model/rules';
import { defaultWriterContext } from 'data/content/writers/context';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { Explanation } from '../common/explanation/ExplanationAuthoring';
import { ActivityScoring } from '../common/responses/ActivityScoring';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import * as ActivityTypes from '../types';
import { Actions } from './actions';
import { OrderingSchema } from './schema';

const store = configureStore();

export const Ordering: React.FC = () => {
  const { dispatch, model, editMode, projectSlug } = useAuthoringElementContext<OrderingSchema>();
  const writerContext = defaultWriterContext({ projectSlug: projectSlug });

  const choices = model.choices.reduce((m: any, c) => {
    m[c.id] = c;
    return m;
  }, {});

  return (
    <TabbedNavigation.Tabs>
      <TabbedNavigation.Tab label="Question">
        <Stem />
        <ChoicesAuthoring
          icon={(choice, index) => <span className="mr-1">{index + 1}.</span>}
          choices={model.choices}
          addOne={() => dispatch(Actions.addChoice(ActivityTypes.makeChoice('')))}
          setAll={(choices: ActivityTypes.Choice[]) => dispatch(Choices.setAll(choices))}
          onEdit={(id, content) => dispatch(Choices.setContent(id, content))}
          onChangeEditorType={(id, editor) => dispatch(Choices.setEditor(id, editor))}
          onRemove={(id) => dispatch(Actions.removeChoiceAndUpdateRules(id))}
          colorMap={model.choiceColors ? new Map(model.choiceColors) : undefined}
          onChangeEditorTextDirection={(id, dir) => dispatch(Choices.setTextDirection(id, dir))}
        />
      </TabbedNavigation.Tab>

      <TabbedNavigation.Tab label="Answer Key">
        <StemDelivery stem={model.stem} context={writerContext} />

        <ResponseChoices
          writerContext={writerContext}
          choices={getCorrectChoiceIds(model).map((id) => choices[id])}
          colorMap={model.choiceColors ? new Map(model.choiceColors) : undefined}
          setChoices={(choices) => dispatch(Actions.setCorrectChoices(choices))}
        />
        <SimpleFeedback partId={model.authoring.parts[0].id} />
        <ActivityScoring partId={model.authoring.parts[0].id} />
        <TargetedFeedback />
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
          model={model}
          onEdit={(t) => dispatch(VariableActions.onUpdateTransformations(t))}
        />
      </TabbedNavigation.Tab>

      <ActivitySettings settings={[shuffleAnswerChoiceSetting(model, dispatch)]} />
    </TabbedNavigation.Tabs>
  );
};

// Owing to migration tool bug, migrated courses lack targeted feedback map for
// ordering. Work around by constructing it as needed when migrating model version
function ensureTargetedMappings(model: OrderingSchemaV2) {
  if (model.authoring.targeted.length === 0) {
    model.authoring.targeted = findTargetedResponses(model, model.authoring.parts[0].id).map(
      (r) => [ruleValue(r.rule).split(' '), r.id],
    );
  }
  return model;
}

export class OrderingAuthoring extends AuthoringElement<OrderingSchema> {
  migrateModelVersion(model: any) {
    return ensureTargetedMappings(
      Maybe.maybe(model.authoring.version).caseOf({
        just: (_v2) => model,
        nothing: () => orderingV1toV2(model),
      }),
    );
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<OrderingSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <Ordering />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, OrderingAuthoring);
