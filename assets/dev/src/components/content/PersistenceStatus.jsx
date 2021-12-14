import React, { useState } from 'react';
// Displays a label indicating persistence state to
// the end user.  Nothing is displayed until an edit
// has been triggered.  Then either 'Saving...' or
// 'All changes saved" is displayed.
export const PersistenceStatus = ({ persistence }) => {
    const [hasSavedOnce, setHasSavedOnce] = useState(false);
    if (persistence !== 'idle' && !hasSavedOnce) {
        setHasSavedOnce(true);
    }
    let label = '';
    if (hasSavedOnce && persistence === 'idle') {
        label = 'All changes saved';
    }
    else if (persistence === 'inflight' || persistence === 'pending') {
        label = 'Saving...';
    }
    return <div>{label}</div>;
};
//# sourceMappingURL=PersistenceStatus.jsx.map