import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { AuthoringButton } from 'components/activities/common/authoring/AuthoringButton';
import React from 'react';
import './RemoveButton.scss';
export const RemoveButton = (props) => (<AuthoringButton ariaLabel="Remove" editMode={props.editMode} action={props.onClick} className="removeButton__button">
    <i style={props.style} className="removeButton__icon material-icons-outlined">
      close
    </i>
  </AuthoringButton>);
export const RemoveButtonConnected = (props) => {
    const { editMode } = useAuthoringElementContext();
    return <RemoveButton {...props} editMode={editMode}/>;
};
//# sourceMappingURL=RemoveButton.jsx.map