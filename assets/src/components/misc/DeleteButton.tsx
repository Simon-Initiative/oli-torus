import React from 'react';
import { classNames, WithClassName } from 'utils/classNames';
import styles from './DeleteButton.modules.scss';

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
      styles.deleteButton,
      'p-0 d-flex align-items-center justify-content-center btn btn-sm btn-delete',
    )}
    aria-label="delete"
    onClick={onClick}
  >
    <i className="fa-solid fa-trash fa-lg"></i>
  </button>
);
