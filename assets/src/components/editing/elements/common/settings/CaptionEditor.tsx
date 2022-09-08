import React from 'react';
import { Caption, CaptionV2, ModelElement } from 'data/content/model/elements/types';
import { Model } from 'data/content/model/elements/factories';
import { Descendant } from 'slate';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { InlineEditor } from './InlineEditor';

const defaultCaption = (text = '') => [Model.p(text)];
interface Props {
  onEdit: (caption: CaptionV2) => void;
  model: ModelElement & { caption?: Caption };
  commandContext: CommandContext;
}

export const CaptionEditor: React.FC<Props> = ({ commandContext, model, onEdit }) => {
  return (
    <InlineEditor
      className="captions-input"
      commandContext={commandContext}
      placeholder="Caption (optional)"
      content={
        (Array.isArray(model.caption)
          ? model.caption
          : defaultCaption(model.caption)) as Descendant[]
      }
      onEdit={onEdit}
    />
  );
};
