import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { AuthoringButton } from 'components/activities/common/authoring/AuthoringButton';
import React, { MouseEventHandler } from 'react';
import './RemoveButton.scss';

type Props = {
  onClick: MouseEventHandler<HTMLButtonElement>;
  className?: string;
  style?: React.CSSProperties;
  editMode: boolean;
};

export const RemoveButton: React.FC<Props> = (props) => (
  <AuthoringButton
    editMode={props.editMode}
    onClick={props.onClick}
    className="removeButton__button"
  >
    <i style={props.style} className="removeButton__icon material-icons-outlined">
      close
    </i>
  </AuthoringButton>
);

export const RemoveButtonConnected: React.FC<Omit<Props, 'editMode'>> = (props) => {
  const { editMode } = useAuthoringElementContext();
  return <RemoveButton {...props} editMode={editMode} />;
};
