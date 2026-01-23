import React from 'react';
import { TriggerPromptEditor } from 'components/editing/elements/trigger/TriggerEditor';
import { AIIcon } from 'components/misc/AIIcon';
import { PageTrigger } from 'data/triggers';

export const PageTriggerEditor: React.FC<{
  trigger: PageTrigger | undefined;
  onEdit: (trigger: PageTrigger | undefined) => void;
}> = React.memo(({ trigger, onEdit }) => {
  return trigger != undefined ? (
    <div className="mt-3 bg-white dark:bg-gray-600 rounded-lg p-3" contentEditable={false}>
      <div className="flex justify-between">
        <h4>
          <AIIcon size="sm" className="inline mr-1" />
          DOT AI Activation Point
        </h4>
        <button onClick={() => onEdit(undefined)} className="btn btn-primary">
          Disable
        </button>
      </div>
      <p>
        When a student visits this page, our AI Assistant <b>DOT</b> will appear and follow your
        customized prompt.
      </p>

      <TriggerPromptEditor
        value={trigger.prompt}
        onPromptChange={(value) => onEdit(Object.assign(trigger, { prompt: value }))}
        promptSamples={[
          'Highlight the most important concepts present on this page',
          'Welcome the student to this page and let them know that you are here to help',
          "Point students towards more practice regarding the concepts on this page's learning objectives",
        ]}
        textareaClassName="mt-2 grow w-full bg-white dark:bg-black rounded-lg p-3 border border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
    </div>
  ) : (
    <div className="mt-3 bg-white dark:bg-gray-600 rounded-lg p-3" contentEditable={false}>
      <div className="flex justify-between">
        <h4>
          <AIIcon size="sm" className="inline mr-1" />
          DOT AI Activation Point
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
