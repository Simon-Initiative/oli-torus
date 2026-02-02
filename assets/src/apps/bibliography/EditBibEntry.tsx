import React from 'react';
import { Tooltip } from 'components/common/Tooltip';

export type EditBibEntryProps = {
  onEdit: () => void;
  icon: string;
  disabled?: boolean;
};

export const EditBibEntry = (props: EditBibEntryProps) => {
  const { onEdit, disabled = false } = props;
  return (
    <Tooltip title="Edit this entry">
      <button
        onClick={() => !disabled && onEdit()}
        type="button"
        className="btn btn-outline-secondary btn-sm"
        disabled={disabled}
        aria-pressed="false"
      >
        <i className={props.icon}></i>
      </button>
    </Tooltip>
  );
};
