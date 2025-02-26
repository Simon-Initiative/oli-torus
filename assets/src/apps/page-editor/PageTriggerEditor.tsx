import React, { useState } from 'react';
import { PageTrigger } from 'data/triggers';

export const PageTriggerEditor: React.FC<{
  trigger: PageTrigger | undefined;
  onEdit: (trigger: PageTrigger | undefined) => void;
}> = React.memo(({ trigger, onEdit }) => {
  const [promptsExpanded, setPromptsExpanded] = useState<boolean>(false);

  const ExpandablePromptHelp = () => (
    <div className={`mt-2 ${promptsExpanded ? 'bg-gray-100 dark:bg-gray-600 rounded-lg' : ''}`}>
      <button
        className="bg-slate-300 rounded-lg p-1"
        onClick={(e) => setPromptsExpanded(!promptsExpanded)}
      >
        View examples of helpful prompts&nbsp;&nbsp; {promptsExpanded ? '^' : '\u22C1'}
      </button>
      {promptsExpanded && (
        <ul className="list-disc list-inside py-2 ml-10">
          <li>&quot;Highlight the most imporant concepts present on this page&quot;</li>
          <li>
            &quot;Welcome the student to this page and let them know that you are here to help&quot;
          </li>
          <li>
            &quot;Point students towards more practice regarding the concepts on this page&apos;s
            learning objectives&quot;
          </li>
        </ul>
      )}
    </div>
  );

  return trigger != undefined ? (
    <div className="mt-3 bg-white dark:bg-gray-600 rounded-lg p-3" contentEditable={false}>
      <div className="flex justify-between">
        <h4>
          <img src="/images/icons/icon-AI.svg" className="inline mr-1" />
          DOT AI Page Trigger Point
        </h4>
        <button onClick={() => onEdit(undefined)} className="btn btn-primary">
          Disable
        </button>
      </div>
      <p className="mt-2">
        Customize a prompt for our AI assistant, DOT, to follow based on learner actions within this
        page.
      </p>

      <h6 className="mt-2">
        <strong>Trigger</strong>
      </h6>

      <p>
        When a student visits this page, DOT will engage with the student guided by the prompt you
        provide below.
      </p>

      <h6 className="mt-2">
        <strong>Prompt</strong>
      </h6>

      <p>
        An AI prompt is a question or instruction given to our AI assistant, DOT, to guide its
        response, helping it generate useful feedback, explanations, or support for learners.
      </p>

      <ExpandablePromptHelp />

      <textarea
        className="mt-2 grow w-full bg-white rounded-lg p-3 border border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
        value={trigger.prompt}
        onChange={(e) => onEdit(Object.assign(trigger, { prompt: e.target.value }))}
      />
    </div>
  ) : (
    <div className="mt-3 bg-white dark:bg-gray-600 rounded-lg p-3" contentEditable={false}>
      <div className="flex justify-between">
        <h4>
          <img src="/images/icons/icon-AI.svg" className="inline mr-1" />
          DOT AI Page Trigger Point
        </h4>
        <button
          onClick={() => onEdit({ id: 'page', type: 'trigger', trigger_type: 'page', prompt: '' })}
          className="btn btn-primary"
        >
          Enable
        </button>
      </div>
    </div>
  );
});

PageTriggerEditor.displayName = 'PageTriggerEditor';
