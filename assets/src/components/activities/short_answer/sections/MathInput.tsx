import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { MathLive } from 'components/common/MathLive';
import { InputText } from 'data/activities/model/rules';

interface MathInputProps {
  input: InputText;
  onEditInput: (input: InputText) => void;
}
export const MathInput: React.FC<MathInputProps> = ({ input, onEditInput }) => {
  const { editMode } = useAuthoringElementContext();

  return (
    <div className="mb-2">
      <MathLive
        value={input.value}
        options={{
          readOnly: !editMode,
          // need this because while keyboard toggle gets hidden if readonly, it apparently
          // isn't automatically restored on change back to nonReadOnly, and authoring context
          // routinely passes through readonly renders before becoming editable
          virtualKeyboardMode: editMode ? 'manual' : 'off',
        }}
        onChange={(latex: string) => onEditInput({ ...input, value: latex, operator: 'equals' })}
      />
    </div>
  );
};
