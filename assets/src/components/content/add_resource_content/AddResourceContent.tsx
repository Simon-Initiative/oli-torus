import { ActivityEditContext } from 'data/content/activity';
import { ResourceContent } from 'data/content/resource';
import React, { useState } from 'react';
import { OverlayTrigger, Popover } from 'react-bootstrap';
import { classNames } from 'utils/classNames';
import guid from 'utils/guid';

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
  const [id] = useState(guid());

  return (
    <>
      <OverlayTrigger
        trigger="click"
        placement={isLast ? 'top-start' : 'bottom-start'}
        rootClose={true}
        overlay={
          <Popover id={id} className="add-resource-popover">
            <Popover.Content className="add-resource-popover-content">{children}</Popover.Content>
          </Popover>
        }
      >
        <div className={classNames('add-resource-content', editMode ? '' : 'disabled')}>
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
      </OverlayTrigger>

      {isLast && (
        <OverlayTrigger
          trigger="click"
          placement="top"
          rootClose={true}
          overlay={
            <Popover id="last-content-add-button" className="add-resource-popover">
              <Popover.Content className="add-resource-popover-content">{children}</Popover.Content>
            </Popover>
          }
        >
          <div className="insert-label my-4 text-center">
            <button disabled={!editMode} className="btn btn-sm btn-light">
              Add Content or Activity
            </button>
          </div>
        </OverlayTrigger>
      )}
    </>
  );
};
