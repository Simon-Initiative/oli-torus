import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { ResponseMultiInputActions } from 'components/activities/response_multi/actions';
import { Dropdown, ResponseMultiInputSchema } from 'components/activities/response_multi/schema';
import { makeChoice } from 'components/activities/types';
import { Choices } from 'data/activities/model/choices';

interface Props {
  input: Dropdown;
}
export const DropdownQuestionEditor: React.FC<Props> = (props) => {
  const { model, dispatch } = useAuthoringElementContext<ResponseMultiInputSchema>();

  return (
    <>
      <ChoicesAuthoring
        icon={(_c, i) => <span>{i + 1}.</span>}
        choices={model.choices.filter(({ id }) => props.input.choiceIds.includes(id))}
        addOne={() => dispatch(ResponseMultiInputActions.addChoice(props.input.id, makeChoice('')))}
        setAll={(choices) =>
          dispatch(ResponseMultiInputActions.reorderChoices(props.input.id, choices))
        }
        onEdit={(id, content) => dispatch(Choices.setContent(id, content))}
        onRemove={(id) => dispatch(ResponseMultiInputActions.removeChoice(props.input.id, id))}
        simpleText
      />
    </>
  );
};
