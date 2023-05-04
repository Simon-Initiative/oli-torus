import React from 'react';
import { classNames } from 'utils/classNames';

export type CloseButtonProps = {
  onClick: () => void;
  editMode: boolean;
  className?: string;
};

export const CloseButton = (props: CloseButtonProps) => (
  <button
    className={classNames('CloseButton close', props.className)}
    disabled={!props.editMode}
    type="button"
    aria-label="Close"
    onClick={props.onClick}
  >
    <i className="fa-solid fa-xmark fa-lg"></i>
  </button>
);
