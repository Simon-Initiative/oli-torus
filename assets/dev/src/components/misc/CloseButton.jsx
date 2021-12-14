import React from 'react';
import { classNames } from 'utils/classNames';
export const CloseButton = (props) => (<button className={classNames(['CloseButton close', props.className])} disabled={!props.editMode} type="button" aria-label="Close" onClick={props.onClick}>
    <span aria-hidden="true">&times;</span>
  </button>);
//# sourceMappingURL=CloseButton.jsx.map