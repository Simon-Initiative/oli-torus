import React, { useState } from 'react';
import { PersistenceState } from 'data/persistence/PersistenceStrategy';

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
