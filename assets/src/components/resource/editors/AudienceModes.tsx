import React from 'react';
import { Dropdown } from 'react-bootstrap';
import { AudienceMode } from 'data/content/resource';
import { classNames } from 'utils/classNames';

export type AudienceModesProps = {
  editMode: boolean; // Whether or not we can edit
  mode?: AudienceMode;
  onEdit: (mode: AudienceMode) => void;
  onRemove: () => void;
};

const descriptions: any = {
  always: 'Always show',
  instructor: 'Show to instructor only',
  feedback: 'Show to instructor and students in review',
  never: 'Never show',
};

export const AudienceModes = (props: AudienceModesProps) => {
  const { editMode, mode, onEdit, onRemove } = props;

  const current = mode && descriptions[mode];
  const options = Object.keys(descriptions).map((m) => {
    return (
      <Dropdown.Item key={m} onClick={() => onEdit(m as AudienceMode)} className={classNames()}>
        {descriptions[m]}
      </Dropdown.Item>
    );
  });

  return (
    <Dropdown className="dropdown mr-2">
      <Dropdown.Toggle variant="outline-primary" size="sm" disabled={!editMode}>
        <span className="leading-normal">
          <i className="fa-solid fa-users mr-1"></i>
          {current}
          <i className="fa-solid fa-caret-down ml-2"></i>
        </span>
      </Dropdown.Toggle>
      <Dropdown.Menu>
        <Dropdown.Header key="header">Content Audience</Dropdown.Header>
        {options}
        {mode && (
          <>
            <Dropdown.Divider />
            <Dropdown.Item key="help" onClick={() => onRemove()}>
              Remove
            </Dropdown.Item>
          </>
        )}
      </Dropdown.Menu>
    </Dropdown>
  );
};
