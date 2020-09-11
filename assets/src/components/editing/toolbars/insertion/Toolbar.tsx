import React, { useRef, useEffect, useState } from 'react';
import { useSlate } from 'slate-react';
import { ToolbarItem, CommandContext } from '../../commands/interfaces';
import Popover from 'react-tiny-popover';
import { hideToolbar, showToolbar, ToolbarButton, Spacer, DropdownToolbarButton } from '../common';
import { shouldShowInsertionToolbar, positionInsertion } from './utils';
import { classNames } from 'utils/classNames';

type InsertionToolbarProps = {
  toolbarItems: ToolbarItem[];
  commandContext: CommandContext;
};

function insertionAreEqual(prevProps: InsertionToolbarProps, nextProps: InsertionToolbarProps) {
  return prevProps.commandContext === nextProps.commandContext
    && prevProps.toolbarItems === nextProps.toolbarItems;
}

export const InsertionToolbar = React.memo((props: InsertionToolbarProps) => {
  const { toolbarItems } = props;
  const ref = useRef();
  const editor = useSlate();

  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  useEffect(() => {
    const el = ref.current as any;

    if (!el) {
      return;
    }

    const reposition = () => positionInsertion(el, editor);

    if (shouldShowInsertionToolbar(editor)) {
      reposition();
      showToolbar(el);
    } else {
      hideToolbar(el);
    }

    window.addEventListener('resize', reposition);
    return () => window.removeEventListener('resize', reposition);
  });

  return (
    <div
      onMouseDown={e => e.preventDefault()}
      ref={ref as any}
      className={classNames(['toolbar add-resource-content', isPopoverOpen ? 'active' : ''])}
    >
      <div className="insert-button-container">
        <Popover
          containerClassName="add-resource-popover"
          onClickOutside={e => setIsPopoverOpen(false)}
          isOpen={isPopoverOpen}
          align="start"
          transitionDuration={0}
          position={['bottom', 'top']}
          content={
            <div className="hovering-toolbar">
              <div className="btn-group btn-group-vertical btn-group-sm" role="group">
                {[...toolbarItems.map((t, i) => {
                  if (t.type !== 'CommandDesc') {
                    return <Spacer key={'spacer-' + i} />;
                  }
                  if (!t.command.precondition(editor)) {
                    return null;
                  }

                  const shared = {
                    style: 'btn-dark',
                    key: t.description(editor),
                    icon: t.icon(editor),
                    tooltip: t.description(editor),
                    command: t.command,
                    context: props.commandContext,
                    setParentPopoverOpen: setIsPopoverOpen,
                  };

                  if (t.command.obtainParameters === undefined) {
                    return <ToolbarButton {...shared} />;
                  }
                  return <DropdownToolbarButton {...shared} />;
                })].filter(x => x)}
              </div>
            </div>
          }>
          {ref => <div ref={ref} className="insert-button"
            onClick={() => setIsPopoverOpen(!isPopoverOpen)}>
            <i className="fa fa-plus"></i>
          </div>}
        </Popover>
      </div>
    </div>
  );
}, insertionAreEqual);
