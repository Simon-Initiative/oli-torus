import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { Dropdown, MultiInput } from 'components/activities/multi_input/schema';
import { ResponseMultiInputSchema } from 'components/activities/response_multi/schema';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { Response, ResponseId } from 'components/activities/types';
import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import { Radio } from 'components/misc/icons/radio/Radio';
import { defaultWriterContext } from 'data/content/writers/context';
import { ResponseMultiInputActions } from '../actions';
import { getInputValues, getUniqueRuleForInput } from '../rules';

interface Props {
  input: MultiInput;
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
    // Rule may combine many input rules, and have multiple matches for this input
    const values = getInputValues(props.response.rule, props.input.id);
    if (values.length > 1) console.log(`input ${props.input.id} w/multiple values: ` + values);

    // questionable what to do with wildcard. Here select all choices
    const selectedValues = values[0] === '.*' ? choices.map((c) => c.id) : values;

    // disjunctive rules allow multiple checked choices for dropdowns, so show as Checkbox
    const orRule = props.response.matchStyle === 'any' || props.response.matchStyle === 'none';
    return (
      <div className="d-flex flex-row">
        <ChoicesDelivery
          unselectedIcon={orRule ? <Checkbox.Unchecked /> : <Radio.Unchecked />}
          selectedIcon={orRule ? <Checkbox.Checked /> : <Radio.Checked />}
          choices={choices}
          selected={selectedValues}
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

  // else non-dropdown: should have only one rule for this input
  const inputRule = getUniqueRuleForInput(props.response.rule, props.input.id);
  return (
    <div className="d-flex flex-row mb-2">
      <div className="flex-grow-1">
        <InputEntry
          key={props.response.id}
          inputType={props.input.inputType}
          // InputEntry edits a response's rule (operation and matching text/number/regexp).
          // Our response may have compound rule, so pass a dummy response object with just
          // the single input rule to be edited. editRule will apply edits to real response
          response={{ id: props.response.id, rule: inputRule } as Response}
          onEditResponseRule={(id, rule) => props.editRule(id, props.input.id, rule)}
        />
      </div>
      <div className="choicesAuthoring__removeButtonContainer">
        {<RemoveButtonConnected onClick={removeInputFromResponse} />}
      </div>
    </div>
  );
};
