import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { MultiInputActions } from 'components/activities/multi_input/actions';
import { makeChoice } from 'components/activities/types';
import { Choices } from 'data/activities/model/choices';
import React from 'react';
export const DropdownQuestionEditor = (props) => {
    const { model, dispatch } = useAuthoringElementContext();
    return (<>
      <ChoicesAuthoring icon={(_c, i) => <span>{i + 1}.</span>} choices={model.choices.filter(({ id }) => props.input.choiceIds.includes(id))} addOne={() => dispatch(MultiInputActions.addChoice(props.input.id, makeChoice('')))} setAll={(choices) => dispatch(MultiInputActions.reorderChoices(props.input.id, choices))} onEdit={(id, content) => dispatch(Choices.setContent(id, content))} onRemove={(id) => dispatch(MultiInputActions.removeChoice(props.input.id, id))} simpleText/>
    </>);
};
//# sourceMappingURL=DropdownQuestionEditor.jsx.map