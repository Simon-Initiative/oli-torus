import React from 'react';
import { useBoundingClientRect } from 'components/hooks/useBoundingRect';
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
  parent: HTMLElement | null;
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
    parent,
    messages,
    onTitleEdit,
    dismissMessage,
    executeAction,
  } = props;
  const scrollPos = useScrollPosition();
  const bounding = useBoundingClientRect(parent, { triggerOnWindowResize: true });

  const showFloating = scrollPos > 300;

  return (
    <>
      <div
        className={classNames(
          'TitleBar',
          'block w-100 align-items-baseline',
          className,
          showFloating ? 'fixed z-10 top-[65px] px-[1px]' : 'h-[40px]',
        )}
        style={showFloating ? { width: bounding?.width, left: bounding?.left } : {}}
      >
        <div
          className={classNames(
            'flex-1 d-flex align-items-baseline',
            showFloating && 'px-4 py-2 backdrop-blur-md bg-body/75 dark:bg-body-dark/75 shadow-lg',
          )}
        >
          <div
            className={classNames(
              'd-flex align-items-baseline flex-grow-1 mr-2',
              showFloating && 'px-4 py-2',
            )}
          >
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
        <div className="p-3">
          {showFloating && (
            <Banner
              dismissMessage={dismissMessage}
              executeAction={executeAction}
              messages={messages}
            />
          )}
        </div>
      </div>

      {showFloating && (
        <>
          <div className="h-[40px]"></div>
        </>
      )}
    </>
  );
};
