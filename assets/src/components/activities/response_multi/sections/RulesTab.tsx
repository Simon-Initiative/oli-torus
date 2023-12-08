import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import {
  Dropdown,
  ResponseMultiInput,
  ResponseMultiInputSchema,
} from 'components/activities/response_multi/schema';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { Response, ResponseId } from 'components/activities/types';
import { Radio } from 'components/misc/icons/radio/Radio';
import { defaultWriterContext } from 'data/content/writers/context';
import { ResponseMultiInputActions } from '../actions';

interface Props {
  input: ResponseMultiInput;
  response: Response;
  toggleCorrectness: (id: string, partId: string, inputId: string) => void;
  editRule: (id: ResponseId, inputId: string, rule: string) => void;
}
export const RulesTab: React.FC<Props> = (props) => {
  const { model, projectSlug, dispatch } = useAuthoringElementContext<ResponseMultiInputSchema>();

  const removeInputFromResponse = () => {
    dispatch(ResponseMultiInputActions.removeInputFromResponse(props.input.id, props.response.id));
  };
  if (props.input.inputType === 'dropdown') {
    const choices = model.choices.filter((choice) =>
      (props.input as Dropdown).choiceIds.includes(choice.id),
    );

    let value = props.response.rule.substring(props.response.rule.indexOf('{') + 1);
    value = value.substring(0, value.indexOf('}'));
    if (value === '.*') value = choices[0].id;

    return (
      <div className="d-flex flex-row">
        <ChoicesDelivery
          unselectedIcon={<Radio.Unchecked />}
          selectedIcon={<Radio.Checked />}
          choices={choices}
          selected={[value]}
          onSelect={(id) => props.toggleCorrectness(id, props.input.partId, props.input.id)}
          isEvaluated={false}
          context={defaultWriterContext({ projectSlug: projectSlug })}
        />
        <div className="choicesAuthoring__removeButtonContainer">
          {<RemoveButtonConnected onClick={removeInputFromResponse} />}
        </div>
      </div>
    );
  }
  return (
    <div className="d-flex flex-row mb-2">
      <div className="flex-grow-1">
        <InputEntry
          key={props.response.id}
          inputType={props.input.inputType}
          response={props.response}
          onEditResponseRule={(id, rule) => props.editRule(id, props.input.id, rule)}
        />
      </div>
      <div className="choicesAuthoring__removeButtonContainer">
        {<RemoveButtonConnected onClick={removeInputFromResponse} />}
      </div>
    </div>
  );
};
