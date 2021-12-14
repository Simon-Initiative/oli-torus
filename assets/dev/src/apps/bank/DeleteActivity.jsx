import React from 'react';
export const DeleteActivity = (props) => {
    const { editMode, onDelete } = props;
    return (<button disabled={!editMode} onClick={() => onDelete()} type="button" className="btn btn-outline-secondary" data-toggle="tooltip" data-placement="top" title="Delete this activity" aria-pressed="false">
      <i className="las la-trash-alt"></i>
    </button>);
};
//# sourceMappingURL=DeleteActivity.jsx.map