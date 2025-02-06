import React, { useState } from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Model } from 'data/content/model/elements/factories';
import { Transforms } from 'slate';

export const insertTrigger = createButtonCommandDesc({
  icon: <i className="fa-solid fa-microchip"></i>,
  category: 'General',
  description: 'DOT Trigger',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.trigger(), { at });
  },
});


interface Props extends EditorProps<ContentModel.TriggerBlock> {}
export const TriggerEditor: React.FC<Props> = ({
  model,
  attributes,
  children,
  commandContext,
}) => {
  const onEdit = useEditModelCallback(model);
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

  return (
    <div className="bg-gray-100 dark:bg-gray-600 rounded-lg p-3" contentEditable={false}>
      <h4>
        <img src="/images/icons/icon-AI.svg" className="inline mr-1" />
        DOT AI Activity Trigger Point
      </h4>
      <p className="mt-2">
        Customize a prompt for our AI assistant, DOT, to follow based on learner actions within this
        activity.
      </p>

      <h6 className="mt-2"><strong>Trigger</strong></h6>

      <p>When a student clicks the <img src="/images/icons/icon-AI.svg" className="inline mr-1"></img> icon
      within this text block, our AI assistant, DOT
      will appear and follow your custom prompt.</p>

      <h6 className="mt-2"><strong>Prompt</strong></h6>

      <p>An AI prompt is a question or instruction given to our AI assistant, DOT, to guide
        its response, helping it generate useful feedback, explanations, or support for learners.</p>

      <ExpandablePromptHelp />

      <textarea
          className="mt-2 grow w-full bg-white rounded-lg p-3 border border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
          value={model.prompt}
          onChange={(e) => onEdit({ prompt: e.target.value })} />
    </div>
  );
};
