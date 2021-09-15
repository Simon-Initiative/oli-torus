import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { inputRef } from 'data/content/model';
import React from 'react';
import { Editor, Transforms } from 'slate';
import { ReactEditor, useEditor } from 'slate-react';
interface InputRefToolbar {
  setEditor: React.Dispatch<React.SetStateAction<ReactEditor & Editor>>;
}
export const InputRefToolbar: React.FC<InputRefToolbar> = (props) => {
  const editor = useEditor();

  React.useEffect(() => {
    props.setEditor(editor);
  }, [editor]);

  return (
    <div>
      <AuthoringButtonConnected
        className="btn-light"
        style={{ borderBottomLeftRadius: 0, borderBottomRightRadius: 0 }}
        action={(e) => {
          e.preventDefault();
          Transforms.insertNodes(editor, inputRef(), { select: true });
        }}
      >
        Add Input
      </AuthoringButtonConnected>
    </div>
  );
};
