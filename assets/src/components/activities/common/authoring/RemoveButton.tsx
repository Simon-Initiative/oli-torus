import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButton } from 'components/activities/common/authoring/AuthoringButton';
import React from 'react';

type Props = {
  onClick: () => void;
  className?: string;
  style?: React.CSSProperties;
  editMode: boolean;
};

export const RemoveButton: React.FC<Props> = (props) => (
  <AuthoringButton
    ariaLabel="Remove"
    editMode={props.editMode}
    action={props.onClick}
    className="text-body-color hover:text-red-500"
  >
    <i className="fa-solid fa-xmark fa-xl"></i>
  </AuthoringButton>
);

export const RemoveButtonConnected: React.FC<Omit<Props, 'editMode'>> = (props) => {
  const { editMode } = useAuthoringElementContext();
  return <RemoveButton {...props} editMode={editMode} />;
};
