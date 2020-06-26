import React from 'react';

// Component for rendering a small action icon with tooltip.  Used for
// the "copy", "open", and "remove" operations

export const Action = ({ icon, onClick, tooltip, id }: any) => {
  return (
    <span id={id} data-toggle="tooltip" data-placement="top" title={tooltip}
      style={ { cursor: 'pointer ' }}>
      <i onClick={onClick} className={icon + ' mr-2'}></i>
    </span>
  );
};