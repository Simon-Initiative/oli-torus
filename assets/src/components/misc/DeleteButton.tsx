import React from 'react';
import { classNames, WithClassName } from 'utils/classNames';

export type DeleteButtonProps = {
  onClick: () => void;
  editMode: boolean;
};

export const DeleteButton = ({
  className,
  editMode,
  onClick,
}: WithClassName<DeleteButtonProps>) => (
  <button
    style={{
      height: 31,
    }}
    disabled={!editMode}
    type="button"
    className={classNames(
      className,
      'p-0 d-flex align-items-center justify-content-center btn btn-sm btn-delete',
    )}
    aria-label="delete"
    onClick={onClick}
  >
    <span className="material-icons" aria-hidden="true">
      delete
    </span>
  </button>
);
