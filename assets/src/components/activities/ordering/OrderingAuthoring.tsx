import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { OrderingModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Actions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { StemAuthoringConnected } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { ChoicesAuthoringConnected } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { HintsAuthoringConnected } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { CATASettingsConnected } from 'components/activities/check_all_that_apply/Settings';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { OrderingChoices } from 'components/activities/ordering/sections/OrderingChoices';

const store = configureStore();

export const Ordering: React.FC<AuthoringElementProps<OrderingModelSchema>> = (props) => {
  const { dispatch } = useAuthoringElementContext();
  // const [activeTab, setActiveTab] = useState()
  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <StemAuthoringConnected />
          <ChoicesAuthoringConnected
            icon={(choice, index) => <span className="mr-1">{index + 1}.</span>}
            choices={props.model.choices}
            addOne={() => dispatch(Actions.addChoice(ActivityTypes.makeChoice('')))}
            setAll={(choices: ActivityTypes.Choice[]) =>
              dispatch(ChoiceActions.setAllChoices(choices))
            }
            onEdit={(id, content) => dispatch(ChoiceActions.editChoiceContent(id, content))}
            onRemove={(id) => dispatch(Actions.removeChoice(id))}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <OrderingChoices
            choices={props.model.choices}
            setChoices={(choices) => dispatch(ChoiceActions.setAllChoices(choices))}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Hints">
          <HintsAuthoringConnected hintsPath="$.authoring.parts[0].hints" />
        </TabbedNavigation.Tab>
      </TabbedNavigation.Tabs>

      {/* <Nav.Link href="/question" label="Question"> */}

      {/* </TabbedNavigation.Tab> */}
      {/* <TabbedNavigation.Tab label="Answer Key"> */}
      {/* <AnswerKeyAuthoring
            stem={props.model.stem}
            choices={props.model.choices}
            selectedChoiceIds={getCorrectChoiceIds(props.model)}
            selectedIcon={<Checkbox.Correct />}
            unselectedIcon={<Checkbox.Unchecked />}
            onSelectChoiceId={(id) => dispatch(Actions.toggleChoiceCorrectness(id))}
          /> */}
      {/* <SimpleFeedback
            correctResponse={getCorrectResponse(props.model)}
            incorrectResponse={getIncorrectResponse(props.model)}
            update={(id, content) => dispatch(ResponseActions.editResponseFeedback(id, content))}
          /> */}

      {/* {isTargetedCATA(props.model) && (
            <TargetedFeedback
              targetedMappings={getTargetedResponseMappings(props.model)}
              toggleChoice={(choiceId, mapping) => {
                dispatch(
                  Actions.editTargetedFeedbackChoices(
                    mapping.response.id,
                    mapping.choiceIds.includes(choiceId)
                      ? mapping.choiceIds.filter((id) => id !== choiceId)
                      : mapping.choiceIds.concat(choiceId),
                  ),
                );
              }}
              updateResponse={(id, content) =>
                dispatch(ResponseActions.editResponseFeedback(id, content))
              }
              addTargetedResponse={() => dispatch(Actions.addTargetedFeedback())}
              unselectedIcon={<Checkbox.Unchecked />}
              selectedIcon={<Checkbox.Checked />}
              onRemove={(id) => dispatch(Actions.removeTargetedFeedback(id))}
            />
          )} */}
      {/* </TabbedNavigation.Tab> */}

      {/* <TabbedNavigation.Tab label="Hints"> */}
      {/* </TabbedNavigation.Tab> */}
      {/* <CATASettingsConnected /> */}
      {/* </TabbedNavigation.Tabs> */}
    </>
  );
};

export class OrderingAuthoring extends AuthoringElement<OrderingModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<OrderingModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <Ordering {...props} />
        </AuthoringElementProvider>
        <ModalDisplay />
      </Provider>,

      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, OrderingAuthoring);
