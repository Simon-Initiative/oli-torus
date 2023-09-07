import React, { useMemo } from 'react';
import { PromptModal } from 'components/misc/PromptModal';
import { AllModelElements } from 'data/content/model/elements/types';
import { getMarkdownWarnings } from '../markdown_editor/markdown_util';

interface Props {
  onConfirm: () => void;
  onCancel: () => void;
  model: AllModelElements[];
}

export const SwitchToMarkdownModal: React.FC<Props> = ({ onConfirm, onCancel, model }) => {
  const warnings = useMemo(() => {
    return getMarkdownWarnings(model);
  }, [model]);

  return (
    <PromptModal
      cancelText="No"
      confirmText="Yes"
      title="Switch to Markdown editor"
      onConfirm={onConfirm}
      onCancel={onCancel}
      className="z-[100001] w-[500px]"
    >
      <p>
        The Markdown editor allows you to author content directly in Markdown, a simple text based
        format for advanced users. Not all content types are available in the Markdown editor.
      </p>
      {warnings.length > 0 && <p>You may lose content related to the following:</p>}
      {warnings.map((warning, i) => (
        <span
          className="inline-block text-white bg-yellow-400 font-medium rounded-full text-sm px-5 py-2.5 text-center mr-2 mb-4 mt-4 dark:focus:ring-yellow-900"
          key={i}
        >
          {warning}
        </span>
      ))}
      <p>Would you like to switch to the Markdown editor?</p>
    </PromptModal>
  );
};
