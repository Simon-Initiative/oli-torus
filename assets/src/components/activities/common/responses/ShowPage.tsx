import React from 'react';
import { TextInput } from 'components/common/TextInput';

export const ShowPage: React.FC<{
  editMode: boolean;
  index: number | undefined;
  onChange: (index: undefined | number) => void;
}> = ({ index, onChange, editMode }) => {
  if (index === undefined) {
    return (
      <div className="alert alert-info">
        <div className="d-flex justify-content-between">
          <div>Branch to another group of content after showing this feedback</div>
          <button className="btn btn-sm btn-primary" onClick={() => onChange(0)}>
            Enable branching
          </button>
        </div>
      </div>
    );
  }
  return (
    <div className="alert alert-info">
      <div className="d-flex">
        <div className="col-sm-4">Display group number:</div>
        <div className="col-sm-2">
          <TextInput
            editMode={editMode}
            label=""
            value={(index as any) + 1 + ''}
            type="numeric"
            style={{ display: 'inline-block' }}
            onEdit={(v) => {
              onChange(parseInt(v) - 1);
            }}
          />
        </div>

        <div className="col-sm-4"></div>

        <div className="col-sm-2">
          <button className="btn btn-sm btn-secondary" onClick={() => onChange(undefined)}>
            Remove
          </button>
        </div>
      </div>
    </div>
  );
};
