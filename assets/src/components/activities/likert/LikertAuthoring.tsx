import {
  Hints as HintsAuthoring,
  Hints,
} from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Choices, Items } from 'data/activities/model/choices';
import * as ContentModel from 'data/content/model/elements/types';
import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import guid from 'utils/guid';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import * as ActivityTypes from '../types';
import { LikertActions } from './actions';
import { LikertModelSchema } from './schema';
import { Radio } from 'components/misc/icons/radio/Radio';
import { MCActions } from '../common/authoring/actions/multipleChoiceActions';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { StemDelivery } from '../common/stem/delivery/StemDelivery';
import { defaultWriterContext } from 'data/content/writers/context';
import { SimpleFeedback } from '../common/responses/SimpleFeedback';
import { TargetedFeedback } from '../common/responses/TargetedFeedback';
import { ChoicesDelivery } from '../common/choices/delivery/ChoicesDelivery';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import { useAuthoringElementContext, AuthoringElementProvider } from '../AuthoringElementProvider';

const Likert = (props: AuthoringElementProps<LikertModelSchema>) => {
  const { dispatch, model, editMode } = useAuthoringElementContext<LikertModelSchema>();

  // for now, we always select the first part for editing correct/feedback/hints.
  const selectedPartId = model.authoring.parts[0].id;
  const selectedItem = model.items.find((i) => i.id == selectedPartId) || model.items[0];

  return (
    <React.Fragment>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <Stem />
          <div>
            <br />
            <p>Choices:</p>
            <ChoicesAuthoring
              icon={<Radio.Unchecked />}
              choices={model.choices}
              setAll={(choices: ActivityTypes.Choice[]) => dispatch(Choices.setAll(choices))}
              onEdit={(id, content) => dispatch(Choices.setContent(id, content))}
              addOne={() => dispatch(LikertActions.addChoice())}
              onRemove={(id) => dispatch(LikertActions.removeChoice(id))}
            />
            <div className="form-check mb-2">
              <input
                className="form-check-input"
                type="checkbox"
                id="descending-toggle"
                aria-label="Checkbox for descending order"
                checked={model.orderDescending}
                onChange={(e: any) => dispatch(LikertActions.setOrderDescending(e.target.checked))}
              />
              <label className="form-check-label" htmlFor="descending-toggle">
                Number Descending
              </label>
            </div>
          </div>

          <p>Questions:</p>
          <ChoicesAuthoring
            choices={model.items}
            setAll={(choices: ActivityTypes.Choice[]) => dispatch(Items.setAll(choices))}
            onEdit={(id, content) => dispatch(Items.setContent(id, content))}
            addOne={() => dispatch(LikertActions.addItem())}
            onRemove={(id) => dispatch(LikertActions.removeItem(id))}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <StemDelivery stem={selectedItem} context={defaultWriterContext()} />

          <ChoicesDelivery
            unselectedIcon={<Radio.Unchecked />}
            selectedIcon={<Radio.Checked />}
            choices={model.choices}
            selected={[getCorrectChoice(model, selectedPartId).id]}
            onSelect={(id) => dispatch(MCActions.toggleChoiceCorrectness(id, selectedPartId))}
            isEvaluated={false}
            context={defaultWriterContext()}
          />
          <SimpleFeedback partId={selectedPartId} />
          <TargetedFeedback
            toggleChoice={(choiceId, mapping) => {
              dispatch(MCActions.editTargetedFeedbackChoice(mapping.response.id, choiceId));
            }}
            addTargetedResponse={() => dispatch(MCActions.addTargetedFeedback())}
            unselectedIcon={<Radio.Unchecked />}
            selectedIcon={<Radio.Checked />}
          />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <Hints partId={selectedPartId} />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Dynamic Variables">
          <VariableEditorOrNot
            editMode={editMode}
            model={model}
            onEdit={(t) => dispatch(VariableActions.onUpdateTransformations(t))}
          />
        </TabbedNavigation.Tab>
      </TabbedNavigation.Tabs>
    </React.Fragment>
  );
};

const store = configureStore();

export class LikertAuthoring extends AuthoringElement<LikertModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<LikertModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <Likert {...props} />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, LikertAuthoring);
