import { CATASchema } from 'components/activities/check_all_that_apply/schema';
import { cataV1toV2 } from 'components/activities/check_all_that_apply/transformations/v2';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { Hints as HintsAuthoring } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { TargetedFeedback } from 'components/activities/common/responses/TargetedFeedback';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Choices } from 'data/activities/model/choices';
import { getCorrectChoiceIds } from 'data/activities/model/responses';
import { defaultWriterContext } from 'data/content/writers/context';
import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { Maybe } from 'tsmonad';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import * as ActivityTypes from '../types';
import { CATAActions } from './actions';

const store = configureStore();

const CheckAllThatApply = () => {
  const { dispatch, model, editMode } = useAuthoringElementContext<CATASchema>();
  return (
    <TabbedNavigation.Tabs>
      <TabbedNavigation.Tab label="Question">
        <Stem />
        <ChoicesAuthoring
          icon={<Checkbox.Unchecked />}
          choices={model.choices}
          addOne={() => dispatch(CATAActions.addChoice(ActivityTypes.makeChoice('')))}
          setAll={(choices: ActivityTypes.Choice[]) => dispatch(Choices.setAll(choices))}
          onEdit={(id, content) => dispatch(Choices.setContent(id, content))}
          onRemove={(id) => dispatch(CATAActions.removeChoiceAndUpdateRules(id))}
        />
      </TabbedNavigation.Tab>

      <TabbedNavigation.Tab label="Answer Key">
        <StemDelivery stem={model.stem} context={defaultWriterContext()} />

        <ChoicesDelivery
          unselectedIcon={<Checkbox.Unchecked />}
          selectedIcon={<Checkbox.Checked />}
          choices={model.choices}
          selected={getCorrectChoiceIds(model)}
          onSelect={(id) => dispatch(CATAActions.toggleChoiceCorrectness(id))}
          isEvaluated={false}
          context={defaultWriterContext()}
        />
        <SimpleFeedback partId={DEFAULT_PART_ID} />
        <TargetedFeedback
          toggleChoice={(choiceId, mapping) => {
            dispatch(
              CATAActions.editTargetedFeedbackChoices(
                mapping.response.id,
                mapping.choiceIds.includes(choiceId)
                  ? mapping.choiceIds.filter((id) => id !== choiceId)
                  : mapping.choiceIds.concat(choiceId),
              ),
            );
          }}
          addTargetedResponse={() => dispatch(CATAActions.addTargetedFeedback())}
          unselectedIcon={<Checkbox.Unchecked />}
          selectedIcon={<Checkbox.Checked />}
        />
      </TabbedNavigation.Tab>

      <TabbedNavigation.Tab label="Hints">
        <HintsAuthoring partId={DEFAULT_PART_ID} />
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

export class CheckAllThatApplyAuthoring extends AuthoringElement<CATASchema> {
  migrateModelVersion(model: any): CATASchema {
    return Maybe.maybe(model.authoring.version).caseOf({
      just: (_v2) => model,
      nothing: () => cataV1toV2(model),
    });
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<CATASchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <CheckAllThatApply />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, CheckAllThatApplyAuthoring);
