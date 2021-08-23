import React from 'react';

export type EditingLockProps = {
  editMode: boolean;
  onChangeEditMode: (state: boolean) => void;
};

export const EditingLock = (props: EditingLockProps) => {
  const { editMode, onChangeEditMode } = props;
  const lockState = editMode ? 'unlock' : 'lock';

  return (
    <button
      onClick={() => onChangeEditMode(!editMode)}
      type="button"
      className="btn btn-outline-secondary mb-2"
      aria-pressed="false"
      data-toggle="tooltip"
      data-placement="top"
      title="Enable or disable editing of this activity"
    >
      <i className={`las la-${lockState}`}></i>
    </button>
  );
};
