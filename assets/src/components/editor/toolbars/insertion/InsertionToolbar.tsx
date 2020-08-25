import React, { useRef, useEffect, useState } from 'react';
import { useSlate } from 'slate-react';
import { ToolbarItem, CommandContext } from '../../commands/interfaces';
import Popover from 'react-tiny-popover';
import { hideToolbar, showToolbar, ToolbarButton, Spacer, DropdownToolbarButton } from '../common';
import { shouldShowInsertionToolbar, positionInsertion } from './utils';
import { classNames } from 'utils/classNames';

export type ToolbarPosition = {
  top?: number,
  bottom?: number,
  left?: number,
  right?: number,
};

type InsertionToolbarProps = {
  toolbarItems: ToolbarItem[];
  commandContext: CommandContext;
  position?: ToolbarPosition;
};

function insertionAreEqual(prevProps: InsertionToolbarProps, nextProps: InsertionToolbarProps) {
  return prevProps.commandContext === nextProps.commandContext
    && prevProps.toolbarItems === nextProps.toolbarItems;
}

export const InsertionToolbar = React.memo((props: InsertionToolbarProps) => {
  const { toolbarItems } = props;
  const ref = useRef();
  const editor = useSlate();

  const [latestClickEvent, setLatestClickEvent] = useState<MouseEvent>();
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  const togglePopover = (e: React.MouseEvent) => {
    console.log('toggling')
    setIsPopoverOpen(!isPopoverOpen);
    setLatestClickEvent(e.nativeEvent);
  };

  useEffect(() => {
    const el = ref.current as any;

    if (!el) {
      return;
    }

    if (shouldShowInsertionToolbar(editor)) {
      positionInsertion(el, editor);
      showToolbar(el);
    } else {
      hideToolbar(el);
    }
  });

  // const content =
  //   <div className="insert-item list-group-item list-group-item-action" key="content"
  //     onClick={() => onAddItem(createDefaultStructuredContent(), index)}>
  //     Content
  //   </div>;

  return (
    // <div ref={(ref as any)} className="toolbar fixed-toolbar" style={style}>
    //   <div className="toolbar-buttons btn-group btn-group-sm" role="group" ref={(ref as any)}>
    //     {buttons.filter(x => x)}
    //   </div>
    // </div>
    <div
      onMouseDown={e => e.preventDefault()}
      ref={ref as any}
      className={classNames(['toolbar add-resource-content', isPopoverOpen ? 'active' : ''])}
    >
      <div className="insert-button-container">
        <Popover
          containerClassName="add-resource-popover"
          onClickOutside={(e) => {
            console.log('click outside')
            if (e !== latestClickEvent) {
              setIsPopoverOpen(false);
            }
          }}
          isOpen={isPopoverOpen}
          align="start"
          transitionDuration={0.25}
          position={['bottom', 'top']}
          content={
            <div className="add-resource-popover-content">
              <div className="list-group">
                {[...toolbarItems.map((t, i) => {
                  if (t.type !== 'CommandDesc') {
                    return <Spacer key={'spacer-' + i} />;
                  }
                  if (!t.command.precondition(editor)) {
                    return null;
                  }

                  const shared = {
                    key: t.description(editor),
                    icon: t.icon(editor),
                    tooltip: t.description(editor),
                    command: t.command,
                    context: props.commandContext,
                  };

                  if (t.command.obtainParameters === undefined) {
                    return <ToolbarButton {...shared} />;
                  }
                  return <DropdownToolbarButton {...shared} />;
                })].filter(x => x)}
              </div>
            </div>
          }>
          {ref => <div ref={ref} className="insert-button" onClick={togglePopover}>
            <i className="fa fa-plus"></i>
          </div>}
        </Popover>
      </div>
    </div>
  );
}, insertionAreEqual);
