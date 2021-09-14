import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { Choices } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { MultiInputActions } from 'components/activities/multi_input/actions';
import { Dropdown, MultiInputSchema } from 'components/activities/multi_input/schema';
import { makeChoice } from 'components/activities/types';
import { CHOICES_PATH } from 'data/activities/model/choiceUtils';
import React from 'react';

interface Props {
  input: Dropdown;
}
export const DropdownQuestionEditor: React.FC<Props> = (props) => {
  const { model, dispatch } = useAuthoringElementContext<MultiInputSchema>();

  return (
    <>
      <Choices
        icon={(_c, i) => <span>{i + 1}.</span>}
        choices={model.choices.filter((choice) => props.input.choiceIds.includes(choice.id))}
        addOne={() => dispatch(MultiInputActions.addChoice(props.input.id, makeChoice('')))}
        setAll={(choices) => dispatch(MultiInputActions.reorderChoices(props.input.id, choices))}
        onEdit={(id, content) =>
          dispatch(ChoiceActions.editChoiceContent(id, content, CHOICES_PATH))
        }
        onRemove={(id) => dispatch(MultiInputActions.removeChoice(props.input.id, id))}
        simpleText
      />
    </>
  );
};
