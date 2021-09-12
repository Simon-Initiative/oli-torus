import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { MCActions } from 'components/activities/common/authoring/actions/multipleChoiceActions';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { Choices } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Dropdown, MultiInputSchema } from 'components/activities/multi_input/schema';
import { Choice, makeChoice, Part } from 'components/activities/types';
import { CHOICES_PATH } from 'data/activities/model/choiceUtils';
import React from 'react';

interface Props {
  part: Part;
  input: Dropdown;
}
export const DropdownQuestionEditor: React.FC<Props> = ({ part, input }) => {
  const { model, dispatch } = useAuthoringElementContext<MultiInputSchema>();

  return (
    <>
      <Choices
        icon={(_c, i) => <span>{i + 1}.</span>}
        choices={model.choices.filter((choice) => input.choiceIds.includes(choice.id))}
        addOne={() => dispatch(ChoiceActions.addChoice(makeChoice('')))}
        setAll={(choices: Choice[]) => dispatch(ChoiceActions.setAllChoices(choices, CHOICES_PATH))}
        onEdit={(id, content) =>
          dispatch(ChoiceActions.editChoiceContent(id, content, CHOICES_PATH))
        }
        onRemove={(id) => dispatch(MCActions.removeChoice(id, part.id, CHOICES_PATH))}
        simpleText
      />
    </>
  );
};
