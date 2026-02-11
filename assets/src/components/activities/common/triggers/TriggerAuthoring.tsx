import React, { useState } from 'react';
import { Button } from 'react-bootstrap';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { HasParts } from 'components/activities/types';
import { TriggerPromptEditor } from 'components/editing/elements/trigger/TriggerEditor';
import { AIIcon } from 'components/misc/AIIcon';
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

  const [currentTriggerIndex, setCurrentTriggerIndex] = useState<string>('');
  const [currentTrigger, setCurrentTrigger] = useState<ActivityTrigger | null>(null);
  const [currentPrompt, setCurrentPrompt] = useState<string>('');

  const onTriggerChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setCurrentTriggerIndex(e.target.value);
    setCurrentTrigger(possible_triggers[+e.target.value]);
  };

  const canAddTrigger = () => currentTrigger != null && currentPrompt != '';

  const addTrigger = () => {
    if (!currentTrigger) return;
    currentTrigger.prompt = currentPrompt;
    dispatch(TriggerActions.addTrigger(currentTrigger, partId));
    resetForm();
  };

  const resetForm = () => {
    setCurrentTriggerIndex('');
    setCurrentTrigger(null);
    setCurrentPrompt('');
  };

  const NewTriggerForm = () => (
    <div className="mt-2">
      <p>
        <b>Action</b>
      </p>
      <select value={currentTriggerIndex} onChange={onTriggerChange} disabled={!editMode}>
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

      <TriggerPromptEditor
        value={currentPrompt}
        onPromptChange={setCurrentPrompt}
        promptSamples={[
          'Give the students another worked example of this question type',
          'Ask the student if they need further assistance answering this question',
          "Point students towards more practice regarding this question's learning objectives",
          'Give students another question of this type',
          'Give students an expert response to this question',
          "Evaluate the student's answer to this question",
        ]}
        textareaClassName="mt-2 w-full bg-inherit"
        disabled={!editMode}
        headingClassName="mt-4"
      />

      <div className="mt-2">
        <Button
          className="btn-primary"
          onClick={addTrigger}
          disabled={!canAddTrigger() || !editMode}
        >
          Save
        </Button>
        <Button className="ml-3 btn-secondary" onClick={resetForm} disabled={!editMode}>
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
        <AIIcon size="sm" className="inline mr-1" />
        DOT AI Activation Point
      </h4>
      <p className="mt-2">
        When a student completes the chosen action(s), our AI assistant <b>DOT</b> will appear and
        follow your customized prompt.
      </p>
      {model.authoring.parts.length > 1 && (
        <p className="mt-2">
          <b>Part {partNumber}</b>
        </p>
      )}

      {NewTriggerForm()}
      {existing_triggers.map((t, i) => TriggerCard(t, i))}
    </>
  );
};

export const TriggerLabel = () => {
  return (
    <span>
      <AIIcon size="sm" className="inline" />
      DOT AI
    </span>
  );
};
