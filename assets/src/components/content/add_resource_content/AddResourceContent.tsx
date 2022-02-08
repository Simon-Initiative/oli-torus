import { ActivityEditContext } from 'data/content/activity';
import { ResourceContent } from 'data/content/resource';
import React, { useState } from 'react';
import { Popover } from 'react-tiny-popover';
import { classNames } from 'utils/classNames';

export type AddCallback = (
  content: ResourceContent,
  index: number,
  a?: ActivityEditContext,
) => void;

// Component that presents a drop down to use to add structure
// content or the any of the registered activities
interface AddResourceContentProps {
  editMode: boolean;
  isLast?: boolean;
}
export const AddResourceContent: React.FC<AddResourceContentProps> = ({
  editMode,
  isLast,
  children,
}) => {
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);
  const [latestClickEvent, setLatestClickEvent] = useState<MouseEvent>();
  const togglePopover = (e: React.MouseEvent) => {
    setIsPopoverOpen(!isPopoverOpen);
    setLatestClickEvent(e.nativeEvent);
  };

  return (
    <>
      <Popover
        containerClassName="add-resource-popover"
        onClickOutside={(e) => {
          if (e !== latestClickEvent) {
            setIsPopoverOpen(false);
          }
        }}
        isOpen={isPopoverOpen}
        align="start"
        positions={['bottom', 'left']}
        content={() => (
          <div onClick={(e) => togglePopover(e)} className="add-resource-popover-content">
            {children}
          </div>
        )}
      >
        <div
          className={classNames([
            'add-resource-content',
            isPopoverOpen ? 'active' : '',
            isLast ? 'add-resource-content-last' : '',
            editMode ? '' : 'disabled',
          ])}
          onClick={togglePopover}
        >
          {editMode && (
            <>
              <div className="insert-button-container">
                <div className="insert-button">
                  <i className="fa fa-plus"></i>
                </div>
              </div>
              <div className="insert-adornment"></div>
            </>
          )}
        </div>
      </Popover>
      <LastAddContentButton
        isLast={typeof isLast === 'boolean' && isLast}
        editMode={editMode}
        togglePopover={togglePopover}
      />
    </>
  );
};

interface LastAddContentButtonProps {
  isLast: boolean;
  editMode: boolean;
  togglePopover: (e: React.MouseEvent) => void;
  content?: React.ReactNode;
}
const LastAddContentButton: React.FC<LastAddContentButtonProps> = ({
  isLast,
  editMode,
  togglePopover,
  content,
}) => {
  if (!isLast) {
    return null;
  }
  return (
    <div className="insert-label my-4 text-center">
      <button onClick={togglePopover} disabled={!editMode} className="btn btn-sm btn-light">
        {content || 'Add Content or Activity'}
      </button>
    </div>
  );
};
