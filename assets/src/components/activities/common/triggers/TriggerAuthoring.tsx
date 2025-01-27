import React, { useState } from 'react';
import { Button } from 'react-bootstrap';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { HasParts } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { getPartById } from 'data/activities/model/utils';
import { ActivityTrigger } from 'data/triggers';
import { RemoveButtonConnected } from '../authoring/RemoveButton';
import { TriggerActions } from './TriggerActions';
import { describeTrigger, getAvailableTriggers } from './TriggerUtils';

interface Props {
  partId: string;
}

export const TriggerAuthoring: React.FC<Props> = ({ partId }) => {
  const { model, dispatch } = useAuthoringElementContext<HasParts>();
  const part = getPartById(model, partId);

  // Add trigger is a mode of the UI
  const [addMode, setAddMode] = useState<boolean>(false);
  const [showPromptHelp, setShowPromptHelp] = useState<boolean>(false);
  const [currentTrigger, setCurrentTrigger] = useState<ActivityTrigger | null>(null);
  const [currentPrompt, setCurrentPrompt] = useState<string>('');

  const canAddTrigger = () => {
    const result = currentTrigger != null && currentPrompt != '';
    console.log('canAddTrigger() => ' + result);
    return result;
  };

  const addTrigger = () => {
    if (!currentTrigger) return;
    currentTrigger.prompt = currentPrompt;
    dispatch(TriggerActions.addTrigger(currentTrigger, partId));
    endAddMode();
  };

  const endAddMode = () => {
    setAddMode(false);
    setCurrentTrigger(null);
  };

  const available_triggers = getAvailableTriggers(model, partId);
  const existing_triggers = part.triggers || [];

  const onTriggerChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const index = +e.target.value;
    setCurrentTrigger(available_triggers[index]);
  };

  return (
    <>
      <h4> DOT AI Activity Trigger Point</h4>
      <p>
        {' '}
        Customize a prompt for our AI assistant, DOT, to follow based on learner actions within this
        activity.
      </p>

      {!addMode && (
        <div className="flex justify-center">
          <Button onClick={(_e) => setAddMode(true)}>+ Create New Trigger</Button>
        </div>
      )}

      {/* modal area for extended prompt mode editing */}
      {addMode && (
        <div>
          <p>
            <img src="/images/icons/icon-ai.svg" className="inline" />
            <b>Trigger</b>
          </p>
          <p>
            An AI trigger is when our AI assistant, DOT, responds to something a learner does, like
            giving feedback or extra help based on their actions.
          </p>

          <select defaultValue="" onChange={onTriggerChange}>
            <option key="instructions" value="" disabled>
              Choose student action...
            </option>
            {available_triggers.map((t, i) => (
              <option key={i} value={i}>
                {describeTrigger(t, part)}
              </option>
            ))}
          </select>

          <p>
            <b>Prompt</b>
          </p>
          <p>
            An AI prompt is a question or instruction given to our AI assistant, DOT, to guide its
            response, helping it generate useful feedback, explanations, or support for learners.
          </p>
          <div>
            <Button onClick={(e) => setShowPromptHelp(!showPromptHelp)}>
              {showPromptHelp ? 'Hide Example Prompts' : 'Show Examples of Helpful Prompts'}
            </Button>
            {showPromptHelp && (
              <ul>
                <li>&quot;Give the students another worked example of this question type&quot;</li>
                <li>
                  &quot;Ask the student if they need further assistance answering this
                  question&quot;
                </li>
                <li>
                  &quot;Point students towards more practice regarding this question&apos;s learning
                  objectives&quot;
                </li>
                <li>&quot;Give students another question of this type&quot;</li>
                <li>&quot;Give students an expert response to this question&quot;</li>
                <li>&quot;Evaluate the student&apos;s answer to this question&quot;</li>
              </ul>
            )}
          </div>
          <p>When triggered, DOT will:</p>
          <textarea className="w-full" onChange={(ev) => setCurrentPrompt(ev.target.value)} />

          <div className="">
            <Button onClick={addTrigger} disabled={!canAddTrigger()}>
              Save
            </Button>
            <Button onClick={endAddMode}>Cancel</Button>
          </div>
        </div>
      )}

      {/* Existing triggers */}
      {!addMode &&
        existing_triggers.map((t, i) => (
          <Card.Card key={i}>
            <Card.Title>
              {i + 1}. {describeTrigger(t, part)}
              <RemoveButtonConnected
                onClick={() => dispatch(TriggerActions.removeTrigger(t, partId))}
              />
            </Card.Title>
            <Card.Content>
              <div className="flex">
                Prompt:
                <input
                  type="text"
                  className="grow"
                  value={t.prompt}
                  onChange={(e) =>
                    dispatch(TriggerActions.setTriggerPrompt(t, partId, e.target.value))
                  }
                />
              </div>
            </Card.Content>
          </Card.Card>
        ))}
    </>
  );
};

export const TriggerLabel = () => {
  return (
    <span>
      <img src="/images/icons/icon-ai.svg" className="inline" />
      DOT AI
    </span>
  );
};
