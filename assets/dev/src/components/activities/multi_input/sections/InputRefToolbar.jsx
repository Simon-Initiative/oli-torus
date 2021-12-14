import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { inputRef } from 'data/content/model/elements/factories';
import React from 'react';
import { Transforms } from 'slate';
import { useSlateStatic } from 'slate-react';
export const InputRefToolbar = (props) => {
    const editor = useSlateStatic();
    React.useEffect(() => {
        props.setEditor(editor);
    }, [editor]);
    return (<div>
      <AuthoringButtonConnected className="btn-light" style={{ borderBottomLeftRadius: 0, borderBottomRightRadius: 0 }} action={(e) => {
            e.preventDefault();
            Transforms.insertNodes(editor, inputRef(), { select: true });
        }}>
        Add Input
      </AuthoringButtonConnected>
    </div>);
};
//# sourceMappingURL=InputRefToolbar.jsx.map