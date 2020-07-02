import React from 'react';
import Popover from 'react-tiny-popover';
import { AnyAaaaRecord } from 'dns';

// Reusable components for settings UIs

export const Action = ({ icon, onClick, tooltip, id }: any) => {
  return (
    <span id={id} data-toggle="tooltip" data-placement="top" title={tooltip}
      style={ { cursor: 'pointer ' }}>
      <i onClick={onClick} className={icon + ' mr-2'}></i>
    </span>
  );
};

export const Caption = ({ caption }: any) => {
  return (
    <p className="text-muted">
      {caption === undefined || caption === '' ? <em>No caption set</em> : caption}
    </p>
  );
};

export const ToolPopupButton = ({
  setIsPopoverOpen,
  isPopoverOpen,
  contentFn,
}: any) => {

  return (
    <div style={ { float: 'right' } }>
      <Popover
        onClickOutside={() => {
          setIsPopoverOpen(false);
        }}
        isOpen={isPopoverOpen}
        padding={25}
        position={['bottom', 'top', 'left', 'right']}
        content={contentFn}>
        {ref => <button ref={ref} onClick={() => setIsPopoverOpen(true)} className="btn btn-light btn-sm mt-1">
            <i className="fas fa-cog"></i>
        </button>}
      </Popover>
    </div>
  );
};
