import React from 'react';
export const ResetButton = ({ disabled = false, shouldShow = true, action }) => {
    if (!shouldShow) {
        return null;
    }
    return (<button aria-label="reset" className="btn btn-primary align-self-start mt-3 mb-3" disabled={disabled} onClick={() => action()} onKeyPress={(e) => (e.key === 'Enter' ? action() : null)}>
      Reset
    </button>);
};
//# sourceMappingURL=ResetButton.jsx.map