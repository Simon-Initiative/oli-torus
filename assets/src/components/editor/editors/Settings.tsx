import React from 'react';
import Popover from 'react-tiny-popover';

// Reusable components for settings UIs

export const onEnterApply = (e: React.KeyboardEvent, onApply: () => void) => {
  if (e.key === 'Enter') {
    onApply();
  }
};

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
      {caption === undefined || caption === '' ? <em>Type caption</em> : caption}
    </p>
  );
};

export const ToolPopupButton = ({
  setIsPopoverOpen,
  isPopoverOpen,
  contentFn,
  label,
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
          <i className="fas fa-cog mr-1"></i>{label ? `${label} Options` : 'Options'}
        </button>}
      </Popover>
    </div>
  );
};
