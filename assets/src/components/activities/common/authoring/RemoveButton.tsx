import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButton } from 'components/activities/common/authoring/AuthoringButton';

type Props = {
  onClick: () => void;
  className?: string;
  style?: React.CSSProperties;
  editMode: boolean;
  mode?: 'authoring' | 'instructor_preview';
};

export const RemoveButton: React.FC<Props> = (props) => (
  <AuthoringButton
    ariaLabel="Remove"
    editMode={props.editMode}
    mode={props.mode}
    action={props.onClick}
    className="text-body-color dark:text-body-color-dark hover:text-red-500"
  >
    <i className="fa-solid fa-xmark fa-xl"></i>
  </AuthoringButton>
);

export const RemoveButtonConnected: React.FC<Omit<Props, 'editMode' | 'mode'>> = (props) => {
  const { editMode, mode } = useAuthoringElementContext();
  return <RemoveButton {...props} editMode={editMode} mode={mode} />;
};
