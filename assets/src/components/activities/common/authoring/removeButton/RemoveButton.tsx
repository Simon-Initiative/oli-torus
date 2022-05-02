import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButton } from 'components/activities/common/authoring/AuthoringButton';
import React from 'react';

import './RemoveButton.scss';

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
