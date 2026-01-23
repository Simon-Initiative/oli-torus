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
  children,
  instructions,
  onDelete,
  showDelete,
}: {
  showDelete: boolean;
  onDelete: any;
  children: any;
  instructions: any;
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
      <p className="mt-2">
        Customize a prompt for our AI assistant, DOT, to follow the student clicks this button.
      </p>

      <h6 className="mt-2">
        <strong>Activation Point</strong>
      </h6>

      {instructions}

      <h6 className="mt-2">
        <strong>Prompt</strong>
        <InfoTip
          title="This is the instruction or question DOT will use to guide its response--such as offering feedback, explanations, or learning support tailored to your learners."
          className="ml-1"
        />
      </h6>

      <p>
        An AI prompt is a question or instruction given to our AI assistant, DOT, to guide its
        response, helping it generate useful feedback, explanations, or support for learners.
      </p>

      <ExpandablePromptHelp
        samples={[
          'Highlight the most important concepts present on this page',
          'Ask the student to summarize the previous paragraphs',
          'Introduce the following video',
        ]}
      />

      {children}
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
      instructions={
        <p>
          When a student clicks the <AIIcon size="sm" className="inline mr-1" /> icon within this
          text block, our AI assistant, DOT will appear and follow your custom prompt.
        </p>
      }
    >
      <textarea
        className="mt-2 grow w-full bg-white dark:bg-black rounded-lg p-3 border border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
        value={model.prompt}
        onChange={(e) => onEdit({ prompt: e.target.value })}
      />
    </TriggerEditorCore>
  );
};
