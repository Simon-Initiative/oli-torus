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
import { parseInputFromRule } from 'components/activities/short_answer/utils';

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
      style={{ width: '150px', height: 61 }}
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

// const Tester = ({ model }: { model: ShortAnswerModelSchema }) => {
//   const [input, setInput] = useState('');
//   const [correctness, setCorrectness] = useState<undefined | 'correct' | 'incorrect'>(undefined);
//   return (
//     <>
//       <div className="input-group">
//         <span
//           className="input-group-text"
//           style={{ borderTopRightRadius: 0, borderBottomRightRadius: 0 }}
//           id={`testInputPrepend-${1}`}
//         >
//           Test answer
//         </span>
//         <input
//           aria-describedby={`testInputPrepend-${1}`}
//           className={`form-control ${
//             correctness === 'correct' ? 'is-valid' : correctness === 'incorrect' ? 'is-invalid' : ''
//           }`}
//           onChange={(e) => setInput(e.target.value)}
//         />
//       </div>

//       <AuthoringButtonConnected
//         onClick={(e) => {
//           Persistence.evaluate(model, [{ attemptGuid: '1', response: { input } }]).then(
//             (result: Persistence.Evaluated) => {
//               console.log('is correct', result.evaluations[0].result.score === 1);
//               if (result.evaluations[0].result.score === 1) {
//                 setCorrectness('correct');
//               } else {
//                 setCorrectness('incorrect');
//               }
//             },
//           );
//         }}
//       >
//         Test input
//       </AuthoringButtonConnected>
//     </>
//   );
// };

interface InputProps {
  inputType: InputType;
  response: ActivityTypes.Response;
  onEditResponseRule: (id: string, rule: string) => void;
}

const Input: React.FC<InputProps> = ({ inputType, response, onEditResponseRule }) => {
  const { editMode } = useAuthoringElementContext();

  const [value, setValue] = useState(parseInputFromRule(response.rule, inputType));

  const onEditRule = (input: string) => {
    if (input !== '.*') {
      setValue(input);

      const rule = inputType === 'numeric' ? `input = {${input}}` : `input like {${input}}`;
      console.log('rule', rule);

      onEditResponseRule(response.id, rule);
    }
  };
  if (value === '.*') {
    return null;
  }

  if (inputType === 'numeric') {
    return <NumericInput response={response} onEditResponseRule={onEditRule} />;
  }

  if (inputType === 'text') {
    return (
      <>
        <input
          disabled={!editMode}
          type="text"
          className="form-control"
          onChange={(e) => onEditRule(e.target.value)}
          value={value}
        />
      </>
    );
  }

  if (inputType === 'textarea') {
    return (
      <textarea
        disabled={!editMode}
        className="form-control"
        onChange={(e) => onEditRule(e.target.value)}
        value={value}
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
          <div className="d-flex">
            <StemAuthoring
              stem={props.model.stem}
              onEdit={(content) => dispatch(StemActions.editStemAndPreviewText(content))}
            />
            <InputTypeDropdown
              editMode={props.editMode}
              inputType={props.model.inputType}
              onChange={(inputType) => dispatch(ShortAnswerActions.setInputType(inputType))}
            />
          </div>
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <div className="d-flex flex-column">
            <StemDelivery stem={model.stem} context={defaultWriterContext()} />
            {props.model.authoring.parts[0].responses.map(
              (response: ActivityTypes.Response, index) => {
                // Handle catchall rule so it doesnt throw
                return (
                  parseInputFromRule(response.rule, props.model.inputType) !== '.*' && (
                    <>
                      <Input
                        key={response.id}
                        inputType={props.model.inputType}
                        response={response}
                        onEditResponseRule={(id, rule) =>
                          dispatch(ShortAnswerActions.editRule(id, rule))
                        }
                      />
                      {/* <Tester model={props.model} /> */}
                    </>
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
