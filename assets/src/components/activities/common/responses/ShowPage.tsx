import React from 'react';
import { TextInput } from 'components/common/TextInput';

export const ShowPage: React.FC<{
  editMode: boolean;
  index: number | undefined;
  onChange: (index: undefined | number) => void;
}> = ({ index, onChange, editMode }) => {
  if (index === undefined) {
    return (
      <div className="float-right">
        <button className="btn btn-sm btn-link" onClick={(_e) => onChange(0)}>
          Trigger pagination change <i className={`tiny-icon las la-code-branch`}></i>
        </button>
      </div>
    );
  }
  return (
    <div className="alert alert-info">
      <div className="d-flex">
        <div className="col-sm-5">Display pagination group number:</div>
        <div className="col-sm-2">
          <TextInput
            editMode={editMode}
            label=""
            value={(index as any) + 1 + ''}
            type="number"
            onEdit={(v) => {
              onChange(parseInt(v) - 1);
            }}
          />
        </div>

        <div className="col-sm-4"></div>

        <div className="col-sm-1">
          <button className="float-right btn btn-sm btn-info" onClick={() => onChange(undefined)}>
            <i className={`tiny-icon las la-trash`}></i>
          </button>
        </div>
      </div>
    </div>
  );
};
