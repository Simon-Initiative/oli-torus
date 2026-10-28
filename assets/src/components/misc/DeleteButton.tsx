import React from 'react';
import { TrashIcon } from 'components/misc/icons/Icons';
import { WithClassName, classNames } from 'utils/classNames';
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
    disabled={!editMode}
    type="button"
    className={classNames(
      className,
      styles.deleteButton,
      'p-0 d-flex self-center align-items-center justify-content-center btn btn-sm btn-delete',
    )}
    aria-label="delete"
    onClick={onClick}
  >
    <TrashIcon />
  </button>
);
