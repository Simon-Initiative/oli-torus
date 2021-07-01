import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { MultipleChoiceModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { MCActions as Actions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { StemAuthoring } from 'components/activities/common/stem/authoring/StemAuthoring';
import { ChoicesAuthoringConnected } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Radio } from 'components/misc/icons/radio/Radio';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { HintsAuthoringConnected } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { AnswerKeyAuthoring } from 'components/activities/common/authoring/answerKey/AnswerKeyAuthoring';
import {
  getCorrectChoice,
  getCorrectResponse,
  getIncorrectResponse,
} from 'components/activities/multiple_choice/utils';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { StemAuthoringConnected } from 'components/activities/common/stem/authoring/StemAuthoringConnected';

const store = configureStore();

const MultipleChoice = (props: AuthoringElementProps<MultipleChoiceModelSchema>) => {
  const { dispatch } = useAuthoringElementContext();
  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <StemAuthoringConnected />

          <ChoicesAuthoringConnected
            icon={<Radio.Unchecked />}
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
          <AnswerKeyAuthoring
            stem={props.model.stem}
            choices={props.model.choices}
            selectedChoiceIds={[getCorrectChoice(props.model).id]}
            selectedIcon={<Radio.Correct />}
            unselectedIcon={<Radio.Unchecked />}
            onSelectChoiceId={(id) => dispatch(Actions.toggleChoiceCorrectness(id))}
          />
          <SimpleFeedback
            correctResponse={getCorrectResponse(props.model)}
            incorrectResponse={getIncorrectResponse(props.model)}
            update={(id, content) => dispatch(ResponseActions.editResponseFeedback(id, content))}
          />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <HintsAuthoringConnected hintsPath="$.authoring.parts[0].hints" />
        </TabbedNavigation.Tab>
        <ActivitySettings settings={[shuffleAnswerChoiceSetting(props.model, dispatch)]} />
      </TabbedNavigation.Tabs>
    </>
  );

  // return (
  //   <React.Fragment>
  //     <Stem
  //       projectSlug={props.projectSlug}
  //       editMode={props.editMode}
  //       stem={props.model.stem}
  //       onEditStem={(content) => dispatch(MCActions.editStem(content))}
  //     />
  //     <Choices
  //       {...sharedProps}
  //       onShuffle={() => dispatch(toggleAnswerChoiceShuffling())}
  //       onAddChoice={() => dispatch(MCActions.addChoice())}
  //       onEditChoice={(id, content) => dispatch(MCActions.editChoice(id, content))}
  //       onRemoveChoice={(id) => dispatch(MCActions.removeChoice(id))}
  //     />
  //     <Feedback
  //       {...sharedProps}
  //       onEditResponse={(id, content) => dispatch(MCActions.editFeedback(id, content))}
  //     />
  //     <Hints
  //       projectSlug={props.projectSlug}
  //       hints={props.model.authoring.parts[0].hints}
  //       editMode={props.editMode}
  //       onAddHint={() => dispatch(MCActions.addHint())}
  //       onEditHint={(id, content) => dispatch(MCActions.editHint(id, content))}
  //       onRemoveHint={(id) => dispatch(MCActions.removeHint(id))}
  //     />
  //   </React.Fragment>
  // );
};

export class MultipleChoiceAuthoring extends AuthoringElement<MultipleChoiceModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MultipleChoiceModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <MultipleChoice {...props} />
        </AuthoringElementProvider>
        <ModalDisplay />
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, MultipleChoiceAuthoring);
