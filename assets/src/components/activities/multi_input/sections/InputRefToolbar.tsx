import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { Model } from 'data/content/model/elements/factories';
import React from 'react';
import { Editor, Transforms } from 'slate';
import { ReactEditor, useSlateStatic } from 'slate-react';
interface InputRefToolbar {
  setEditor: React.Dispatch<React.SetStateAction<ReactEditor & Editor>>;
}
export const InputRefToolbar: React.FC<InputRefToolbar> = (props) => {
  const editor = useSlateStatic();

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
          Transforms.insertNodes(editor, Model.inputRef(), { select: true });
        }}
      >
        Add Input
      </AuthoringButtonConnected>
    </div>
  );
};
