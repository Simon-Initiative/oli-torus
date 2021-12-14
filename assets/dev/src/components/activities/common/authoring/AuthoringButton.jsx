import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import React from 'react';
import { classNames } from 'utils/classNames';
export const AuthoringButton = (props) => {
    return (<button aria-label={props.ariaLabel || ''} style={props.style} className={classNames(['btn', props.className])} disabled={props.disabled || !props.editMode} type="button" onClick={(e) => props.action(e)} onKeyPress={(e) => (e.key === 'Enter' ? props.action(e) : null)}>
      {props.children}
    </button>);
};
export const AuthoringButtonConnected = (props) => {
    const { editMode } = useAuthoringElementContext();
    return <AuthoringButton {...props} editMode={editMode}/>;
};
//# sourceMappingURL=AuthoringButton.jsx.map