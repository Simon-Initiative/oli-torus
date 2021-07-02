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
import { Stem } from '../common/Stem';
import { Feedback } from './sections/Feedback';
import { Hints } from '../common/Hints';
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
import {
  isOperator,
  operator,
  parseInputFromRule,
  parseOperatorFromRule,
} from 'components/activities/short_answer/utils';
import * as Persistence from 'data/persistence/activity';
import {
  AuthoringButton,
  AuthoringButtonConnected,
} from 'components/activities/common/authoring/AuthoringButton';
import { Popover } from 'react-tiny-popover';

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
    <div className="mb-3">
      <select
        style={{ width: '150px' }}
        disabled={!editMode}
        className="form-control"
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
    </div>
  );
};

const Tester = ({ model }: { model: ShortAnswerModelSchema }) => {
  const [input, setInput] = useState('');
  const [correctness, setCorrectness] = useState<undefined | 'correct' | 'incorrect'>(undefined);
  return (
    <>
      <div className="input-group">
        <span
          className="input-group-text"
          style={{ borderTopRightRadius: 0, borderBottomRightRadius: 0 }}
          id={`testInputPrepend-${1}`}
        >
          Test answer
        </span>
        <input
          aria-describedby={`testInputPrepend-${1}`}
          className={`form-control ${
            correctness === 'correct' ? 'is-valid' : correctness === 'incorrect' ? 'is-invalid' : ''
          }`}
          onChange={(e) => setInput(e.target.value)}
        />
      </div>

      <AuthoringButtonConnected
        onClick={(e) => {
          Persistence.evaluate(model, [{ attemptGuid: '1', response: { input } }]).then(
            (result: Persistence.Evaluated) => {
              console.log('is correct', result.evaluations[0].result.score === 1);
              if (result.evaluations[0].result.score === 1) {
                setCorrectness('correct');
              } else {
                setCorrectness('incorrect');
              }
            },
          );
        }}
      >
        Test input
      </AuthoringButtonConnected>
    </>
  );
};

interface InputProps {
  inputType: InputType;
  response: ActivityTypes.Response;
  onEditResponseRule: (id: string, rule: string) => void;
}
const Input: React.FC<InputProps> = ({ inputType, response, onEditResponseRule }) => {
  const { editMode } = useAuthoringElementContext();

  const [value, setValue] = useState(parseInputFromRule(response.rule));
  const [operator, setOperator] = useState(
    inputType === 'numeric' ? parseOperatorFromRule(response.rule) : 'eq',
  );
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

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
  const numericOptions: { value: operator; displayValue: string }[] = [
    { value: 'gt', displayValue: '>' },
    { value: 'gte', displayValue: '≥' },
    { value: 'eq', displayValue: '=' },
    { value: 'lte', displayValue: '≤' },
    { value: 'lt', displayValue: '<' },
  ];
  const makeNumericRule = (operator: operator, input: string) => {
    switch (operator) {
      case 'gt':
        return `input > {${input}}`;
      case 'gte':
        return `input > {${input}} || input = {${input}}`;
      case 'eq':
        return `input = {${input}}`;
      case 'lt':
        return `input < {${input}}`;
      case 'lte':
        return `input < {${input}} || input = {${input}}`;
      default:
        return `input = {${input}}`;
    }
  };
  const setNumericRule = (operator: operator, input: string) => {
    console.log('operator', operator, 'input', input);

    console.log('new rule', makeNumericRule(operator, input));
    onEditResponseRule(response.id, makeNumericRule(operator, input));
  };
  if (inputType === 'numeric') {
    return (
      <div className="d-flex">
        <select
          style={{ width: '60px' }}
          disabled={!editMode}
          className="form-control"
          value={operator}
          onChange={(e) => {
            if (!isOperator(e.target.value)) {
              return;
            }
            setOperator(e.target.value);
            setNumericRule(e.target.value, value);
          }}
          name="question-type"
          id="question-type"
        >
          {numericOptions.map((option) => (
            <option key={option.value} value={option.value}>
              {option.displayValue}
            </option>
          ))}
        </select>
        <input
          style={{ fontFamily: 'monospace' }}
          disabled={!editMode}
          type="number"
          className="form-control"
          onChange={(e) => {
            setValue(e.target.value);
            console.log('new rule', makeNumericRule(operator, e.target.value));
            onEditResponseRule(response.id, makeNumericRule(operator, e.target.value));
          }}
          value={value}
        />
      </div>
    );
  }
  if (inputType === 'text') {
    return (
      <>
        <Popover
          containerClassName="add-resource-popover"
          isOpen={isPopoverOpen}
          // align="end"
          positions={['right', 'top', 'bottom']}
          content={<div className="settings__menu"></div>}
        >
          <span
            onMouseOver={() => setIsPopoverOpen(true)}
            onMouseOut={() => setIsPopoverOpen(false)}
          >
            How does this work?
          </span>
        </Popover>
        <input
          style={{ fontFamily: 'monospace' }}
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
        style={{ fontFamily: 'monospace' }}
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
          <StemAuthoring
            stem={props.model.stem}
            onEdit={(content) => dispatch(StemActions.editStemAndPreviewText(content))}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <div className="d-flex flex-column">
            <StemDelivery stem={model.stem} context={defaultWriterContext()} />
            <InputTypeDropdown
              editMode={props.editMode}
              inputType={props.model.inputType}
              onChange={(inputType) => dispatch(ShortAnswerActions.setInputType(inputType))}
            />
            {props.model.authoring.parts[0].responses.map(
              (response: ActivityTypes.Response, index) =>
                parseInputFromRule(response.rule) !== '.*' && (
                  <>
                    <Input
                      key={response.id}
                      inputType={props.model.inputType}
                      response={response}
                      onEditResponseRule={(id, rule) =>
                        dispatch(ShortAnswerActions.editRule(id, rule))
                      }
                    />
                    <Tester model={props.model} />
                  </>
                ),
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
