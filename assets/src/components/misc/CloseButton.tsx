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
    <span aria-hidden="true">&times;</span>
  </button>
);
