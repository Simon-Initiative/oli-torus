import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { MCActions } from 'components/activities/common/authoring/actions/multipleChoiceActions';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { Choices } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { hintsByPart } from 'data/activities/model/hintUtils';
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
import { getChoices } from 'data/activities/model/choiceUtils';

interface Props {
  part: Part;
  input: MultiDropdownInput;
}
export const DropdownEditor: React.FC<Props> = ({ part, input }) => {
  const { model, dispatch } = useAuthoringElementContext<MultiInputSchema>();

  const choicesPath = multiInputChoicesPath(part.id);

  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <Choices
            icon={(_c, i) => <span>{i + 1}.</span>}
            choices={input.choices}
            addOne={() => dispatch(ChoiceActions.addChoice(makeChoice('')))}
            setAll={(choices: Choice[]) =>
              dispatch(ChoiceActions.setAllChoices(choices, choicesPath))
            }
            onEdit={(id, content) =>
              dispatch(ChoiceActions.editChoiceContent(id, content, choicesPath))
            }
            onRemove={(id) => dispatch(MCActions.removeChoice(id, part.id, choicesPath))}
            simpleText
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <select
            onChange={(e) => dispatch(MCActions.toggleChoiceCorrectness(e.target.value, part.id))}
            className="custom-select mb-3"
          >
            {getChoices(model, choicesPath).map((c) => (
              <option
                selected={getCorrectChoice(model, part.id, choicesPath).id === c.id}
                key={c.id}
                value={c.id}
              >
                {toSimpleText({ children: c.content.model })}
              </option>
            ))}
          </select>
          <SimpleFeedback partId={part.id} />
          <TargetedFeedback
            toggleChoice={(choiceId, mapping) => {
              dispatch(MCActions.editTargetedFeedbackChoice(mapping.response.id, choiceId));
            }}
            addTargetedResponse={() =>
              dispatch(MCActions.addTargetedFeedback(part.id, choicesPath))
            }
            // Change this to a dropdown
            unselectedIcon={<Radio.Unchecked />}
            selectedIcon={<Radio.Checked />}
          />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <Hints partId={part.id} hintsByPart={hintsByPart(part.id)} />
        </TabbedNavigation.Tab>
      </TabbedNavigation.Tabs>
    </>
  );
};
