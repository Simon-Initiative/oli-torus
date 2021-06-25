import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { AuthoringButton } from 'components/activities/common/authoring/AuthoringButton';
import React, { MouseEventHandler } from 'react';

type Props = {
  onClick: MouseEventHandler<HTMLButtonElement>;
  className?: string;
  style?: React.CSSProperties;
  editMode: boolean;
};

export const RemoveButton: React.FC<Props> = (props) => (
  <AuthoringButton editMode={props.editMode} onClick={props.onClick} className="RemoveButton p-0">
    <i
      style={{
        cursor: 'default',
        pointerEvents: 'none',
        display: 'block',
        ...props.style,
      }}
      className="material-icons-outlined"
    >
      close
    </i>
  </AuthoringButton>
);

export const RemoveButtonConnected: React.FC<Omit<Props, 'editMode'>> = (props) => {
  const { editMode } = useAuthoringElementContext();
  return <RemoveButton {...props} editMode={editMode} />;
};
