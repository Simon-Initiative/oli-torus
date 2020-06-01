import React from 'react';

export const Reset
  = ({ onClick, hasMoreAttempts } : { onClick : () => void, hasMoreAttempts: boolean}) =>
  <button disabled={!hasMoreAttempts} onClick={onClick}
    className="btn btn-primary muted">Retry</button>;
