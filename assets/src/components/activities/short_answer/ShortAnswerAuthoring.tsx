import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { ShortAnswerModelSchema, InputType, isInputType } from './schema';
import * as ActivityTypes from '../types';
import { Feedback } from './sections/Feedback';
import { ShortAnswerActions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { StemAuthoring } from 'components/activities/common/stem/StemAuthoring';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { HintsAuthoringConnected } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { defaultWriterContext } from 'data/content/writers/context';
import { NumericInput } from 'components/activities/short_answer/sections/numericInput/NumericInput';
import {
  makeRule,
  parseInputFromRule,
  parseOperatorFromRule,
  RuleOperator,
} from 'components/activities/common/responses/authoring/rules';
import { TextInput } from 'components/activities/short_answer/sections/TextInput';

const store = configureStore();

const inputs: { value: string; displayValue: string }[] = [
  { value: 'numeric', displayValue: 'Number' },
  { value: 'text', displayValue: 'Short Answer' },
  { value: 'textarea', displayValue: 'Paragraph' },
];

type InputTypeDropdownProps = {
  editMode: boolean;
  onChange: (inputType: InputType) => void;
  inputType: InputType;
};
export const InputTypeDropdown = ({ onChange, editMode, inputType }: InputTypeDropdownProps) => {
  const handleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    if (!isInputType(e.target.value)) {
      return;
    }
    onChange(e.target.value);
  };

  return (
    <select
      style={{ height: 61 }}
      disabled={!editMode}
      className="ml-2 form-control"
      value={inputType}
      onChange={handleChange}
      name="question-type"
      id="question-type"
    >
      {inputs.map((option) => (
        <option key={option.value} value={option.value}>
          {option.displayValue}
        </option>
      ))}
    </select>
  );
};

interface InputProps {
  inputType: InputType;
  response: ActivityTypes.Response;
  onEditResponseRule: (id: string, rule: string) => void;
}

const Input: React.FC<InputProps> = ({ inputType, response, onEditResponseRule }) => {
  const { editMode } = useAuthoringElementContext();

  type Input = string | [string, string];
  const [{ operator, input }, setState] = useState({
    input: parseInputFromRule(response.rule),
    operator: parseOperatorFromRule(response.rule),
  });

  const onEditRule = (inputState: { input: Input; operator: RuleOperator }) => {
    if (input !== '.*') {
      setState(inputState);
      onEditResponseRule(response.id, makeRule(inputState.operator, inputState.input));
    }
  };
  if (input === '.*') {
    return null;
  }

  const shared = {
    state: { operator, input },
    setState: onEditRule,
  };

  if (inputType === 'numeric') {
    return <NumericInput {...shared} />;
  }

  if (inputType === 'text') {
    return <TextInput {...shared} />;
  }

  if (inputType === 'textarea') {
    return (
      <textarea
        disabled={!editMode}
        className="form-control"
        onChange={(e) => onEditRule({ operator: operator, input: e.target.value })}
        value={input}
      />
    );
  }
  return null;
};

const ShortAnswer = (props: AuthoringElementProps<ShortAnswerModelSchema>) => {
  const { dispatch, model } = useAuthoringElementContext();
  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <div className="row mb-2">
            <div className="col-md-8">
              <StemAuthoring
                stem={props.model.stem}
                onEdit={(content) => dispatch(StemActions.editStemAndPreviewText(content))}
              />
            </div>
            <div className="col-md-4">
              <InputTypeDropdown
                editMode={props.editMode}
                inputType={props.model.inputType}
                onChange={(inputType) => dispatch(ShortAnswerActions.setInputType(inputType))}
              />
            </div>
          </div>
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <div className="d-flex flex-column mb-2">
            <StemDelivery stem={model.stem} context={defaultWriterContext()} />
            {props.model.authoring.parts[0].responses.map(
              (response: ActivityTypes.Response, index) => {
                // Handle catchall rule so it doesnt throw
                return (
                  parseInputFromRule(response.rule) !== '.*' && (
                    <Input
                      key={response.id}
                      inputType={props.model.inputType}
                      response={response}
                      onEditResponseRule={(id, rule) =>
                        dispatch(ShortAnswerActions.editRule(id, rule))
                      }
                    />
                  )
                );
              },
            )}
          </div>

          {/* <SimpleFeedback
            correctResponse={getCorrectResponse(props.model)}
            incorrectResponse={getIncorrectResponse(props.model)}
            update={(id, content) => dispatch(ResponseActions.editResponseFeedback(id, content))}
          /> */}

          {/* {isTargetedCATA(props.model) && (
            <TargetedFeedback
              choices={props.model.choices}
              targetedMappings={getTargetedResponseMappings(props.model)}
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
              updateResponse={(id, content) =>
                dispatch(ResponseActions.editResponseFeedback(id, content))
              }
              addTargetedResponse={() => dispatch(CATAActions.addTargetedFeedback())}
              unselectedIcon={<Checkbox.Unchecked />}
              selectedIcon={<Checkbox.Checked />}
              onRemove={(id) => dispatch(CATAActions.removeTargetedFeedback(id))}
            />
          )} */}
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <HintsAuthoringConnected hintsPath="" />
        </TabbedNavigation.Tab>
      </TabbedNavigation.Tabs>
    </>
  );

  const sharedProps = {
    model: props.model,
    editMode: props.editMode,
  };

  return (
    <div>
      <Feedback
        {...sharedProps}
        projectSlug={props.projectSlug}
        onAddResponse={() => dispatch(ShortAnswerActions.addResponse())}
        onRemoveResponse={(id) => dispatch(ShortAnswerActions.removeReponse(id))}
        onEditResponseRule={(id, rule) => dispatch(ShortAnswerActions.editRule(id, rule))}
        onEditResponse={(id, content) => dispatch(ShortAnswerActions.editFeedback(id, content))}
      />
    </div>
  );
};

export class ShortAnswerAuthoring extends AuthoringElement<ShortAnswerModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<ShortAnswerModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <ShortAnswer {...props} />
        </AuthoringElementProvider>
        <ModalDisplay />
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, ShortAnswerAuthoring);
