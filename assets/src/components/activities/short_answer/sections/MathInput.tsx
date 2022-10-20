import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { InputText } from 'data/activities/model/rules';
import { MathLive } from 'components/common/MathLive';

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
        }}
        onChange={(latex: string) => onEditInput({ ...input, value: latex, operator: 'equals' })}
      />
    </div>
  );
};
