import React from 'react';
export const SubmitButton = ({ shouldShow = true, disabled = false, onClick }) => {
    if (!shouldShow) {
        return null;
    }
    return (<button aria-label="submit" className="btn btn-primary align-self-start mt-3 mb-3" disabled={disabled} onClick={onClick}>
      Submit
    </button>);
};
//# sourceMappingURL=SubmitButton.jsx.map