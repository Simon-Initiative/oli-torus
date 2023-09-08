import React from 'react';
import { PromptModal } from 'components/misc/PromptModal';

interface Props {
  onConfirm: () => void;
  onCancel: () => void;
}
export const SwitchToSlateModal: React.FC<Props> = ({ onConfirm, onCancel }) => {
  return (
    <PromptModal
      cancelText="No"
      confirmText="Yes"
      title="Switch to rich text editor"
      onConfirm={onConfirm}
      onCancel={onCancel}
      className="z-[100001]"
    >
      The rich text editor is our default content editor based on a &quot;what you see is what you
      get&quot; model. As long as you do not use any content elements that are not supported by the
      the Markdown editor, you can switch back. Would you like to switch now?
    </PromptModal>
  );
};
