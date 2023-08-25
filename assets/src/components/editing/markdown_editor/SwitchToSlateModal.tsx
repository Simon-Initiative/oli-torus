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
      title="Switch to slate editor"
      onConfirm={onConfirm}
      onCancel={onCancel}
      className="z-[100001]"
    >
      The Slate base editor is a rich WYSIWYG editor. As long as you do not use any content elements
      that are not supported by the this editor, you can switch back and forth. Would you like to
      switch now?
    </PromptModal>
  );
};
