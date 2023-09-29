import React, { useState } from 'react';
import { useScrollPosition } from 'components/hooks/useScrollPosition';
import { Banner } from 'components/messages/Banner';
import { MessageAction, Message as Msg } from 'data/messages/messages';
import { classNames } from 'utils/classNames';
import { TextEditor } from '../TextEditor';

export type TitleBarProps = {
  title: string; // The title of the resource
  editMode: boolean; // Whether or not the user is editing
  onTitleEdit: (title: string) => void;
  children: any;
  className?: string;
  dismissMessage: (message: Msg) => void;
  executeAction: (message: Msg, action: MessageAction) => void;
  messages: Msg[];
};

// Title bar component that allows title bar editing and displays
// any collection of child components
//
// When scrolling the editor, the title bar will float to the top
// of the screen and remain there until the user scrolls back to the top
export const TitleBar = (props: TitleBarProps) => {
  const {
    editMode,
    className,
    title,
    children,
    messages,
    onTitleEdit,
    dismissMessage,
    executeAction,
  } = props;
  const scrollPos = useScrollPosition();

  const [titleBarTop, setTitleBarTop] = useState<number | null>(null);
  const [titleBarHeight, setTitleBarHeight] = useState<number | null>(null);
  const workspaceHeaderHeight = 64;
  const showFloating =
    titleBarTop && titleBarHeight && scrollPos > titleBarTop - workspaceHeaderHeight;

  return (
    <>
      <div
        ref={(ref) => {
          if (ref?.offsetTop && !titleBarTop) {
            const boundingClientRect = ref.getBoundingClientRect();

            setTitleBarTop(boundingClientRect.top);
            setTitleBarHeight(boundingClientRect.height);
          }
        }}
        className={classNames('TitleBar', 'sticky w-100 align-items-baseline z-40', className)}
        style={{ top: workspaceHeaderHeight }}
      >
        <div
          className={classNames(
            'flex-1 d-flex align-items-baseline py-2',
            showFloating ? 'px-4 backdrop-blur-md bg-body/75 dark:bg-body-dark/75 shadow-lg' : '',
          )}
        >
          <div className={classNames('d-flex align-items-baseline flex-grow-1 mr-2')}>
            <TextEditor
              onEdit={onTitleEdit}
              model={title}
              showAffordances={true}
              size="large"
              allowEmptyContents={false}
              editMode={editMode}
            />
          </div>
          {children}
        </div>
        {showFloating && (
          <Banner
            dismissMessage={dismissMessage}
            executeAction={executeAction}
            messages={messages}
          />
        )}
      </div>
    </>
  );
};
