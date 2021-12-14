import React, { useState } from 'react';
import { Popover } from 'react-tiny-popover';
import { classNames } from 'utils/classNames';
export const AddResourceContent = ({ editMode, isLast, children, }) => {
    const [isPopoverOpen, setIsPopoverOpen] = useState(false);
    const [latestClickEvent, setLatestClickEvent] = useState();
    const togglePopover = (e) => {
        setIsPopoverOpen(!isPopoverOpen);
        setLatestClickEvent(e.nativeEvent);
    };
    return (<>
      <Popover containerClassName="add-resource-popover" onClickOutside={(e) => {
            if (e !== latestClickEvent) {
                setIsPopoverOpen(false);
            }
        }} isOpen={isPopoverOpen} align="start" positions={['bottom', 'left']} content={() => <div className="add-resource-popover-content">{children}</div>}>
        <div className={classNames([
            'add-resource-content',
            isPopoverOpen ? 'active' : '',
            isLast ? 'add-resource-content-last' : '',
            editMode ? '' : 'disabled',
        ])} onClick={togglePopover}>
          {editMode && (<>
              <div className="insert-button-container">
                <div className="insert-button">
                  <i className="fa fa-plus"></i>
                </div>
              </div>
              <div className="insert-adornment"></div>
            </>)}
        </div>
      </Popover>
      <LastAddContentButton isLast={typeof isLast === 'boolean' && isLast} editMode={editMode} togglePopover={togglePopover}/>
    </>);
};
const LastAddContentButton = ({ isLast, editMode, togglePopover, content, }) => {
    if (!isLast) {
        return null;
    }
    return (<div className="insert-label my-4 text-center">
      <button onClick={togglePopover} disabled={!editMode} className="btn btn-sm btn-light">
        {content || 'Add Content or Activity'}
      </button>
    </div>);
};
//# sourceMappingURL=AddResourceContent.jsx.map