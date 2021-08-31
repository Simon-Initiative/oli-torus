import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { MCActions } from 'components/activities/common/authoring/actions/multipleChoiceActions';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { Choices } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { getChoices } from 'components/activities/common/choices/authoring/choiceUtils';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { hintsByPart } from 'components/activities/common/hints/authoring/hintUtils';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { TargetedFeedback } from 'components/activities/common/responses/TargetedFeedback';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { MultiDropdownInput, multiInputChoicesPath } from 'components/activities/multi_input/utils';
import { Choice, makeChoice, Part } from 'components/activities/types';
import { Radio } from 'components/misc/icons/radio/Radio';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { toSimpleText } from 'data/content/text';
import React from 'react';

interface Props {
  part: Part;
  input: MultiDropdownInput;
}
export const DropdownQuestionEditor: React.FC<Props> = ({ part, input }) => {
  const { model, dispatch } = useAuthoringElementContext<MultiInputSchema>();

  const choicesPath = multiInputChoicesPath(part.id);

  return (
    <>
      <Choices
        icon={(_c, i) => <span>{i + 1}.</span>}
        choices={input.choices}
        addOne={() => dispatch(ChoiceActions.addChoice(makeChoice('')))}
        setAll={(choices: Choice[]) => dispatch(ChoiceActions.setAllChoices(choices, choicesPath))}
        onEdit={(id, content) =>
          dispatch(ChoiceActions.editChoiceContent(id, content, choicesPath))
        }
        onRemove={(id) => dispatch(MCActions.removeChoice(id, part.id, choicesPath))}
        simpleText
      />
    </>
  );
};
