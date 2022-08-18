import React from 'react';
import { PaginationMode } from 'data/content/resource';

export type PaginationModesProps = {
  editMode: boolean; // Whether or not we can edit
  mode: PaginationMode;
  onEdit: (mode: PaginationMode) => void;
};

const descriptions: any = {
  normal: 'Allow user to paginate through items',
  manualReveal: 'Allow user to reveal items one at a time',
  automatedReveal: 'Reveal items with automation',
};

export const PaginationModes = (props: PaginationModesProps) => {
  const { editMode, mode, onEdit } = props;

  const current = descriptions[mode];
  const options = Object.keys(descriptions).map((m) => {
    return (
      <button className="dropdown-item" key={m} onClick={() => onEdit(m as PaginationMode)}>
        {descriptions[m]}
      </button>
    );
  });

  return (
    <div className="form-inline">
      <div className="dropdown">
        <button
          type="button"
          disabled={!editMode}
          className={'btn btn-sm dropdown-toggle btn-purpose'}
          data-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
        >
          {current}
        </button>
        <div className="dropdown-menu dropdown-menu-right">{options}</div>
      </div>
    </div>
  );
};
