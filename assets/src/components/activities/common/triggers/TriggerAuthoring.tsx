import React, { useState } from 'react';
import { Button } from 'react-bootstrap';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { HasParts } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { getPartById } from 'data/activities/model/utils';
import { ActivityTrigger } from 'data/triggers';
import { RemoveButtonConnected } from '../authoring/RemoveButton';
import { TriggerActions } from './TriggerActions';
import { describeTrigger, getPossibleTriggers, hasTrigger } from './TriggerUtils';

interface Props {
  partId: string;
}

export const TriggerAuthoring: React.FC<Props> = ({ partId }) => {
  const { model, dispatch, editMode } = useAuthoringElementContext<HasParts>();

  const part = getPartById(model, partId);
  const partNumber = model.authoring.parts.findIndex((p) => p.id === partId) + 1;
  const possible_triggers = getPossibleTriggers(model, partId);
  const existing_triggers = part.triggers || [];

  // Add trigger is a mode of the UI
  const [addMode, setAddMode] = useState<boolean>(false);
  const [promptsExpanded, setPromptsExpanded] = useState<boolean>(false);
  const [currentTrigger, setCurrentTrigger] = useState<ActivityTrigger | null>(null);
  const [currentPrompt, setCurrentPrompt] = useState<string>('');

  const onTriggerChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setCurrentTrigger(possible_triggers[+e.target.value]);
  };

  const canAddTrigger = () => currentTrigger != null && currentPrompt != '';

  const addTrigger = () => {
    if (!currentTrigger) return;
    currentTrigger.prompt = currentPrompt;
    dispatch(TriggerActions.addTrigger(currentTrigger, partId));
    endAddMode();
  };

  const endAddMode = () => {
    setAddMode(false);
    setCurrentTrigger(null);
    setPromptsExpanded(false);
  };

  const ExpandablePromptHelp = () => (
    <div className={`mt-2 ${promptsExpanded ? 'bg-gray-100 dark:bg-gray-600 rounded-lg' : ''}`}>
      <Button
        className="bg-gray-500 hover:bg-gray-700 rounded-lg m-1"
        onClick={(e) => setPromptsExpanded(!promptsExpanded)}
      >
        View examples of helpful prompts&nbsp;&nbsp; {promptsExpanded ? '^' : '\u22C1'}
      </Button>
      {promptsExpanded && (
        <ul className="list-disc list-inside py-2 ml-10">
          <li>&quot;Give the students another worked example of this question type&quot;</li>
          <li>
            &quot;Ask the student if they need further assistance answering this question&quot;
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
  );

  const NewTriggerForm = () => (
    <div className="mt-2">
      <p>
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
        {possible_triggers.map((t, i) => {
          const triggerText = describeTrigger(t, part);
          return (
            <option
              key={i}
              value={i}
              disabled={hasTrigger(model, partId, t)}
              // if truncated, include full form in tooltip
              title={triggerText.endsWith('...)') ? describeTrigger(t, part, null) : ''}
            >
              {triggerText}
            </option>
          );
        })}
      </select>

      <p className="mt-4">
        <b>Prompt</b>
      </p>
      <p>
        An AI prompt is a question or instruction given to our AI assistant, DOT, to guide its
        response, helping it generate useful feedback, explanations, or support for learners.
      </p>

      {ExpandablePromptHelp()}

      <p className="mt-4">The course author would like DOT to:</p>
      <textarea
        className="w-full bg-inherit"
        onChange={(ev) => setCurrentPrompt(ev.target.value)}
      />

      <div className="mt-2">
        <Button className="btn-primary" onClick={addTrigger} disabled={!canAddTrigger()}>
          Save
        </Button>
        <Button className="ml-3 btn-secondary" onClick={endAddMode}>
          Cancel
        </Button>
      </div>
    </div>
  );

  const TriggerCard = (t: ActivityTrigger, i: number) => (
    <Card.Card key={'trigger-' + i}>
      <Card.Title>
        {i + 1}. {describeTrigger(t, part)}
        <div className="flex-grow-1"></div>
        <RemoveButtonConnected onClick={() => dispatch(TriggerActions.removeTrigger(t, partId))} />
      </Card.Title>
      <Card.Content>
        <div className="flex">
          <label className="pt-2 pr-1">Prompt:</label>
          <textarea
            className="grow bg-inherit"
            value={t.prompt}
            disabled={!editMode}
            onChange={(e) => dispatch(TriggerActions.setTriggerPrompt(t, partId, e.target.value))}
          />
        </div>
      </Card.Content>
    </Card.Card>
  );

  return (
    <>
      <h4>
        <img src="/images/icons/icon-ai.svg" className="inline mr-1" />
        DOT AI Activity Trigger Point
      </h4>
      <p className="mt-2">
        Customize a prompt for our AI assistant, DOT, to follow based on learner actions within this
        activity.
      </p>
      {model.authoring.parts.length > 1 && (
        <p className="mt-2">
          <b>Part {partNumber}</b>
        </p>
      )}

      {!addMode ? (
        <>
          <div className="mt-2 flex justify-center py-4">
            <Button onClick={(_e) => setAddMode(true)} disabled={!editMode}>
              + Create New Trigger
            </Button>
          </div>

          {existing_triggers.map((t, i) => TriggerCard(t, i))}
        </>
      ) : (
        NewTriggerForm()
      )}
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
