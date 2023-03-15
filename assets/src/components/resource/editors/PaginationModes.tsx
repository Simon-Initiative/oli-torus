import React from 'react';
import { PaginationMode } from 'data/content/resource';
import { Dropdown } from 'react-bootstrap';

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
      <Dropdown.Item key={m} onClick={() => onEdit(m as PaginationMode)}>
        {descriptions[m]}
      </Dropdown.Item>
    );
  });

  return (
    <div className="form-inline">
      <Dropdown className="dropdown">
        <Dropdown.Toggle disabled={!editMode} className={'btn btn-purpose'} size="sm">
          {current}
        </Dropdown.Toggle>
        <Dropdown.Menu>{options}</Dropdown.Menu>
      </Dropdown>
    </div>
  );
};
