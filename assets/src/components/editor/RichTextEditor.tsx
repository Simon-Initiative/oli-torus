import React from 'react';
import { RichText } from 'components/activities/multiple_choice/schema';
import { Editor } from 'components/editor/Editor';
import { getToolbarForResourceType } from 'components/resource/toolbar';

type RichTextEditorProps = {
  editMode: boolean;
  text: RichText;
  onEdit: (text: RichText) => void;
};
export const RichTextEditor = ({ editMode, text, onEdit, children }:
  React.PropsWithChildren<RichTextEditorProps>) => {
  // TODO: Figure out why editMode initializes to `null`, remove hardcoded value
  return (
    <React.Fragment>
      {children}
      <div style={{
        border: '1px solid #e5e5e5',
        borderRadius: '2px',
        color: '#666',
        padding: '10px',
        fontFamily: 'Inter',
        fontSize: '11px',
        margin: '4px 0 10px 0',
      }}>
        <Editor editMode={true} value={text} onEdit={onEdit}
          toolbarItems={getToolbarForResourceType(1)} />
      </div>
    </React.Fragment>
  );
};
