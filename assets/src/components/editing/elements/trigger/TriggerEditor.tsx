import React from 'react';
import { Transforms } from 'slate';
import { ExpandablePromptHelp } from 'components/common/ExpandablePromptHelp';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import { AIIcon } from 'components/misc/AIIcon';
import { DeleteButton } from 'components/misc/DeleteButton';
import { InfoTip } from 'components/misc/InfoTip';
import { Model } from 'data/content/model/elements/factories';
import * as ContentModel from 'data/content/model/elements/types';

let triggerPromptEditorId = 0;

interface TriggerPromptEditorProps {
  value: string;
  onPromptChange: (value: string) => void;
  promptSamples: readonly string[];
  textareaClassName?: string;
  disabled?: boolean;
  headingClassName?: string;
}

export const TriggerPromptEditor: React.FC<TriggerPromptEditorProps> = ({
  value,
  onPromptChange,
  promptSamples,
  textareaClassName,
  disabled,
  headingClassName = 'mt-2',
}) => {
  const promptHelpIdRef = React.useRef<string>();
  const promptHeadingIdRef = React.useRef<string>();
  if (!promptHelpIdRef.current) {
    triggerPromptEditorId += 1;
    promptHelpIdRef.current = `trigger-prompt-help-${triggerPromptEditorId}`;
    promptHeadingIdRef.current = `trigger-prompt-heading-${triggerPromptEditorId}`;
  }

  return (
    <>
      <h6 id={promptHeadingIdRef.current} className={headingClassName}>
        <strong>Prompt</strong>
        <InfoTip
          title="This is the instruction or question DOT will use to guide its response--such as offering feedback, explanations, or learning support tailored to your learners."
          className="ml-2"
        />
      </h6>

      <ExpandablePromptHelp samples={promptSamples} />

      <span id={promptHelpIdRef.current} className="sr-only">
        Examples of helpful prompts are available above. Use the button to expand or collapse them.
      </span>

      <textarea
        className={textareaClassName}
        value={value}
        onChange={(e) => onPromptChange(e.target.value)}
        disabled={disabled}
        aria-describedby={promptHelpIdRef.current}
        aria-labelledby={promptHeadingIdRef.current}
      />
    </>
  );
};

export const insertTrigger = createButtonCommandDesc({
  icon: <AIIcon size="sm" className="inline mr-1" />,
  category: 'General',
  description: 'DOT Activation Point',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.trigger(), { at });
  },
});

export const TriggerEditorCore = ({
  instructions,
  onDelete,
  showDelete,
  promptSamples,
  promptValue,
  onPromptChange,
  promptTextareaClassName,
  promptDisabled,
}: {
  showDelete: boolean;
  onDelete: any;
  instructions: any;
  promptSamples: string[];
  promptValue: string;
  onPromptChange: (value: string) => void;
  promptTextareaClassName: string;
  promptDisabled?: boolean;
}) => {
  return (
    <div className="bg-gray-100 dark:bg-gray-600 rounded-lg p-3" contentEditable={false}>
      <div className="flex justify-between">
        <h4>
          <AIIcon size="sm" className="inline mr-1" />
          DOT AI Activation Point
        </h4>
        {showDelete ? <DeleteButton onClick={() => onDelete()} editMode={true} /> : null}
      </div>

      {instructions}

      <TriggerPromptEditor
        value={promptValue}
        onPromptChange={onPromptChange}
        promptSamples={promptSamples}
        textareaClassName={promptTextareaClassName}
        disabled={promptDisabled}
      />
    </div>
  );
};

interface Props extends EditorProps<ContentModel.TriggerBlock> {}
export const TriggerEditor: React.FC<Props> = ({ model }) => {
  const onEdit = useEditModelCallback(model);
  return (
    <TriggerEditorCore
      showDelete={false}
      onDelete={() => onEdit(undefined as any)}
      promptValue={model.prompt}
      onPromptChange={(value) => onEdit({ prompt: value })}
      promptTextareaClassName="mt-2 grow w-full bg-white dark:bg-black rounded-lg p-3 border border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
      promptSamples={[
        'Highlight the most important concepts present on this page',
        'Ask the student to summarize the previous paragraphs',
        'Introduce the following video',
      ]}
      instructions={
        <p>
          When a student clicks the <AIIcon size="sm" className="inline mr-1" /> icon within this
          text block, our AI assistant, DOT will appear and follow your custom prompt.
        </p>
      }
    />
  );
};
