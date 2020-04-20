import React, { useState } from 'react';
import { PersistenceState } from 'data/persistence/PersistenceStrategy';

// Displays a label indicating persistence state to
// the end user.  Nothing is displayed until an edit
// has been triggered.  Then either 'Saving...' or
// 'All changes saved" is displayed.
export const PersistenceStatus = ({ persistence }
  : {persistence: PersistenceState}) => {

  const [hasSavedOnce, setHasSavedOnce] = useState(false);

  if (persistence !== 'idle' && !hasSavedOnce) {
    setHasSavedOnce(true);
  }

  let label = '';
  if (hasSavedOnce && persistence === 'idle') {
    label = 'All changes saved';
  } else if (persistence === 'inflight' || persistence === 'pending') {
    label = 'Saving...';
  }

  return (
    <div>
      {label}
    </div>
  );
};
