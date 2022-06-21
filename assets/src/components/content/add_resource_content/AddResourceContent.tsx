import { ActivityEditContext } from 'data/content/activity';
import { ResourceContent } from 'data/content/resource';
import React, { useState } from 'react';
import { OverlayTrigger, Popover } from 'react-bootstrap';
import { classNames } from 'utils/classNames';
import guid from 'utils/guid';

import styles from './AddResourceContent.modules.scss';

export type AddCallback = (
  content: ResourceContent,
  index: number[],
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
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  return (
    <>
      <OverlayTrigger
        trigger="click"
        placement={isLast ? 'top-start' : 'bottom-start'}
        rootClose={true}
        overlay={
          <Popover id={id} className={styles.addResourcePopover}>
            <Popover.Content className={styles.addResourcePopoverContent}>
              {children}
            </Popover.Content>
          </Popover>
        }
        onToggle={(show) => setIsPopoverOpen(show)}
      >
        <div
          className={classNames(
            styles.addResourceContent,
            !editMode && styles.disabled,
            isPopoverOpen && styles.active,
          )}
        >
          {editMode && (
            <>
              <div className={styles.insertButtonContainer}>
                <div className={styles.insertButton}>
                  <i className="fa fa-plus"></i>
                </div>
              </div>
              <div className={styles.insertAdornment}></div>
            </>
          )}
        </div>
      </OverlayTrigger>
    </>
  );
};
