import React, { ReactNode } from 'react';

export const ScoreInput: React.FC<{
  score: number;
  onChange: (score: number) => void;
  children: ReactNode;
  editMode: boolean;
}> = ({ score, onChange, children, editMode }) => {
  return (
    <div className='flex flex-row gap-2 items-center'>
      <label className='flex items-center'>{children}</label>
      <input
        type="number"
        style={{width: '60px'}}
        className="form-control inline-block"
        disabled={!editMode}
        onChange={(e) => onChange(parseFloat(e.target.value || '0'))}
        value={score}
        step={0.1}
      />
    </div>
  );
};
