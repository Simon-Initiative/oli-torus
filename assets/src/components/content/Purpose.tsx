import React from 'react';

import { PurposeTypes } from 'data/content/resource';

export type PurposeProps = {
  editMode: boolean; // Whether or not we can edit
  purpose: string;
  onEdit: (purpose: string) => void;
};

export const Purpose = (props: PurposeProps) => {
  const { editMode, purpose, onEdit } = props;

  const options = PurposeTypes.map((p) => (
    <button className="dropdown-item" key={p.value} onClick={() => onEdit(p.value)}>
      {p.label}
    </button>
  ));

  const purposeLabel = PurposeTypes.find((p) => p.value === purpose)?.label;

  return (
    <div className="form-inline">
      <div className="dropdown">
        <button
          type="button"
          id="purposeTypeButton"
          disabled={!editMode}
          className="btn btn-sm dropdown-toggle btn-purpose mr-3"
          data-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
        >
          {purposeLabel}
        </button>
        <div className="dropdown-menu dropdown-menu-right" aria-labelledby="purposeTypeButton">
          {options}
        </div>
      </div>
    </div>
  );
};
