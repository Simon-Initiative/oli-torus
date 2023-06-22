import React from 'react';
import { Editor, Transforms } from 'slate';
import { ReactEditor, useSlateStatic } from 'slate-react';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { Model } from 'data/content/model/elements/factories';

interface InputRefToolbar {
  setEditor: React.Dispatch<React.SetStateAction<ReactEditor & Editor>>;
}
export const InputRefToolbar: React.FC<InputRefToolbar> = (props) => {
  const editor = useSlateStatic();

  React.useEffect(() => {
    props.setEditor(editor);
  }, [editor]);

  return (
    <div className="d-flex flex-row justify-end my-2">
      <AuthoringButtonConnected
        className="btn-primary btn-sm"
        action={(e) => {
          e.preventDefault();
          Transforms.insertNodes(editor, Model.inputRef(), { select: true });
        }}
      >
        Add Input
      </AuthoringButtonConnected>
    </div>
  );
};
