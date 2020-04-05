import React from 'react';

export type CloseButtonProps = {
  onClick: () => void,
  editMode: boolean,
};

export const CloseButton = (props: CloseButtonProps) => (
  <button
    disabled={!props.editMode}
    type="button"
    className="close"
    aria-label="Close"
    onClick={props.onClick}>
    <span aria-hidden="true">&times;</span>
  </button>
);
