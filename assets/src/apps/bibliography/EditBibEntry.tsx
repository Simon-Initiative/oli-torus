import { Tooltip } from 'components/common/Tooltip';
import React from 'react';

export type EditBibEntryProps = {
  onEdit: () => void;
  icon: string;
};

export const EditBibEntry = (props: EditBibEntryProps) => {
  const { onEdit } = props;
  return (
    <Tooltip title="Edit this entry">
      <button
        onClick={() => onEdit()}
        type="button"
        className="btn btn-outline-secondary btn-sm"
        aria-pressed="false"
      >
        <i className={props.icon}></i>
      </button>
    </Tooltip>
  );
};
