import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { elementsOfType } from 'components/editing/utils';
import { inputRef, InputRef } from 'data/content/model';
import React from 'react';
import { Editor, Transforms } from 'slate';
import { ReactEditor, useEditor } from 'slate-react';
interface InputRefToolbar {
  setEditor: React.Dispatch<React.SetStateAction<ReactEditor & Editor>>;
}
export const InputRefToolbar: React.FC<InputRefToolbar> = (props) => {
  const editor = useEditor();
  const { dispatch, model, editMode } = useAuthoringElementContext<MultiInputSchema>();

  React.useEffect(() => {
    props.setEditor(editor);
  }, [editor]);

  React.useEffect(() => {
    if (!editMode) {
      return;
    }

    // Handle copy and paste, moving to other tabs
    const difference = (minuend: Map<any, any>, subtrahend: Map<any, any>) =>
      new Set([...minuend].filter(([k]) => !subtrahend.has(k)).map(([, v]) => v));

    // Reconciliation logic
    const inputRefs = new Map(
      elementsOfType<InputRef>(editor, 'input_ref').map((input) => [input.id, input]),
    );
    // const parts = getParts(model).reduce(
    //   (acc, part) => acc.set(part.id, part),
    //   new Map<ID, Part>(),
    // );
    // const extraInputRefs = difference(inputRefs, parts);
    // const extraParts = difference(parts, inputRefs);
    // if (extraInputRefs.size > 3 || extraParts.size > 3) {
    //   return;
    // }
    // console.log('setting input refs', inputRefs);
    // extraInputRefs.forEach((inputRef) => dispatch(MultiInputActions.addPart(inputRef)));
    // return props.setInputRefs(() => inputRefs);

    // if (/* Part Ids do not match all input part Ids */) {
    //   // Make sure all input refs match the part ids here
    //   // Figure out how to reconcile if necessary
    // }
  }, [model, editor, editMode]);

  return (
    <div>
      <AuthoringButtonConnected
        className="btn-light"
        style={{ borderBottomLeftRadius: 0, borderBottomRightRadius: 0 }}
        action={(e) => {
          e.preventDefault();
          ReactEditor.focus(editor);
          Transforms.insertNodes(editor, inputRef(), { select: true, hanging: true });
        }}
      >
        Add Input
      </AuthoringButtonConnected>
    </div>
  );
};
