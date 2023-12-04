import React, { ReactNode } from 'react';

export const ParticipationInput: React.FC<{
  value: number;
  onChange: (score: number) => void;
  children: ReactNode;
  editMode: boolean;
}> = ({ value, onChange, children, editMode }) => {
  return (
    <div className="mb-2">
      <label className="flex items-center">{children}</label>
      <input
        type="number"
        style={{ width: '60px' }}
        className="form-control inline-block"
        disabled={!editMode}
        onChange={(e) => onChange(parseInt(e.target.value || '0'))}
        value={value}
        step={0.1}
      />
    </div>
  );
};

export const ParticipationDateInput: React.FC<{
  value?: string;
  onChange: (val: string) => void;
  children: ReactNode;
  editMode: boolean;
}> = ({ value, onChange, children, editMode }) => {
  return (
    <div className="mb-2">
      <label className="flex items-center">{children}</label>
      <input
        type="date"
        style={{ width: '160px' }}
        className="form-control inline-block mr-2"
        disabled={!editMode}
        onChange={(e) => onChange(e.target.value || '')}
        value={value}
        step={0.1}
      />
      <button onClick={(e) => onChange('')}>Clear</button>
    </div>
  );
};
