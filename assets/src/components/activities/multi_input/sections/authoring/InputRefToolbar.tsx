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

const difference = (minuend: Map<any, any>, subtrahend: Map<any, any>) =>
  new Set([...minuend].filter(([k]) => !subtrahend.has(k)).map(([, v]) => v));

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

// if (addedInputRefs.length) {
//   console.log('added input ref', addedInputRefs);
// }
// if (removedInputRefs.length) {
// console.log('removed input ref', removedInputRefs);
// }

// const difference = (minuend: Map<any, any>, subtrahend: Map<any, any>) =>
//   new Set([...minuend].filter(([k]) => !subtrahend.has(k)).map(([, v]) => v));

// // Reconciliation logic
// const inputRefs = (elementsOfType(editor, 'input_ref') as InputRef[]).reduce(
//   (acc, ref) => acc.set(ref.partId, ref),
//   new Map<ID, InputRef>(),
// );
// const parts = getParts(model).reduce(
//   (acc, part) => acc.set(part.id, part),
//   new Map<ID, Part>(),
// );
// const extraInputRefs: Set<InputRef> = difference(inputRefs, parts);
// const extraParts: Set<Part> = difference(parts, inputRefs);
// extraInputRefs.forEach((inputRef) => {
//   console.log('extra refs', extraInputRefs);
//   MultiInputActions.addPart(inputRef)(model, post);
// });
// extraParts.forEach((part) => {
//   console.log('extra parts', extraParts);
//   MultiInputActions.removePart(part.id, inputRefs)(model, post);
// });
