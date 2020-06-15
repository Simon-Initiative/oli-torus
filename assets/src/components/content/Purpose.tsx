import React from 'react';

import { Purpose as PurposeType } from 'data/content/resource';

export type PurposeProps = {
  editMode: boolean,              // Whether or not we can edit
  purpose: string,
  purposes: PurposeType[],
  onEdit: (purpose: string) => void,
};

export const Purpose = (props: PurposeProps) => {

  const { editMode, purpose, onEdit, purposes } = props;

  const options = purposes
    .map(p => <option key={p.value} value={p.value}>{p.label}</option>);

  return (
    <div className="form-inline mr-4">
      <label className="mr-sm-2"><small>Purpose:</small></label>
      <select
        disabled={!editMode}
        value={purpose}
        onChange={v => onEdit(v.target.value)}
        className="custom-select custom-select-sm">
        {options}
      </select>
    </div>
  );
};
