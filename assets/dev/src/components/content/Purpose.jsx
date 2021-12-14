import React from 'react';
export const Purpose = (props) => {
    var _a;
    const { editMode, purpose, onEdit, purposes } = props;
    const options = purposes.map((p) => (<button className="dropdown-item" key={p.value} onClick={() => onEdit(p.value)}>
      {p.label}
    </button>));
    const purposeLabel = (_a = purposes.find((p) => p.value === purpose)) === null || _a === void 0 ? void 0 : _a.label;
    return (<div className="form-inline">
      <div className="dropdown">
        <button type="button" id="purposeTypeButton" disabled={!editMode} className="btn btn-sm dropdown-toggle btn-purpose mr-3" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
          {purposeLabel}
        </button>
        <div className="dropdown-menu" aria-labelledby="purposeTypeButton">
          {options}
        </div>
      </div>
    </div>);
};
//# sourceMappingURL=Purpose.jsx.map