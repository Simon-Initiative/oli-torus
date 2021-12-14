import React from 'react';
export const DeleteButton = (props) => (<button style={{
        height: 31,
    }} disabled={!props.editMode} type="button" className="p-0 mr-2 d-flex align-items-center justify-content-center btn btn-sm btn-delete" aria-label="delete" onClick={props.onClick}>
    <span className="material-icons" aria-hidden="true">
      delete
    </span>
  </button>);
//# sourceMappingURL=DeleteButton.jsx.map