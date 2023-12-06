import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { Dropdown, MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { Response, ResponseId } from 'components/activities/types';
import { Radio } from 'components/misc/icons/radio/Radio';
import { defaultWriterContext } from 'data/content/writers/context';

interface Props {
  input: MultiInput;
  response: Response;
  toggleCorrectness: (id: string, partId: string, inputId: string) => void;
  editRule: (id: ResponseId, inputId: string, rule: string) => void;
}
export const RulesTab: React.FC<Props> = (props) => {
  const { model, projectSlug } = useAuthoringElementContext<MultiInputSchema>();

  if (props.input.inputType === 'dropdown') {
    const choices = model.choices.filter((choice) =>
      (props.input as Dropdown).choiceIds.includes(choice.id),
    );

    let value = props.response.rule.substring(props.response.rule.indexOf('{') + 1);
    value = value.substring(0, value.indexOf('}'));
    if (value === '.*') value = choices[0].id;

    return (
      <>
        <ChoicesDelivery
          unselectedIcon={<Radio.Unchecked />}
          selectedIcon={<Radio.Checked />}
          choices={choices}
          selected={[value]}
          onSelect={(id) => props.toggleCorrectness(id, props.input.partId, props.input.id)}
          isEvaluated={false}
          context={defaultWriterContext({ projectSlug: projectSlug })}
        />
      </>
    );
  }
  return (
    <div className="d-flex flex-column mb-2">
      <InputEntry
        key={props.response.id}
        inputType={props.input.inputType}
        response={props.response}
        onEditResponseRule={(id, rule) => props.editRule(id, props.input.id, rule)}
      />
    </div>
  );
};
