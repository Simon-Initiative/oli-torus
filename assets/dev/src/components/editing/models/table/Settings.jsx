import React, { useEffect, useRef, useState } from 'react';
import * as Settings from 'components/editing/models/settings/Settings';
export const TableSettings = (props) => {
    // Which selection is active, URL or in course page
    const [model, setModel] = useState(props.model);
    const ref = useRef();
    useEffect(() => {
        // Inits the tooltips, since this popover rendres in a react portal
        // this was necessary
        if (ref !== null && ref.current !== null) {
            window.$('[data-toggle="tooltip"]').tooltip();
        }
    });
    const setCaption = (caption) => setModel(Object.assign({}, model, { caption }));
    const applyButton = (disabled) => (<button onClick={(e) => {
            e.stopPropagation();
            e.preventDefault();
            props.onEdit(model);
        }} disabled={disabled} className="btn btn-primary ml-1">
      Apply
    </button>);
    return (<div className="settings-editor-wrapper">
      <div className="settings-editor" ref={ref}>
        <div className="d-flex justify-content-between mb-2">
          <div>Table</div>

          <div>
            <Settings.Action icon="fas fa-trash" tooltip="Remove Table" id="remove-button" onClick={() => props.onRemove()}/>
          </div>
        </div>

        {applyButton(!props.editMode)}
      </div>
    </div>);
};
//# sourceMappingURL=Settings.jsx.map