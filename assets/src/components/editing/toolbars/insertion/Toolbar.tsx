import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';
import React, { useEffect, useRef, useState } from 'react';
import { Popover } from 'react-tiny-popover';
import { useFocused, useSlate } from 'slate-react';
import { classNames } from 'utils/classNames';
import { CommandContext, ToolbarItem } from '../../commands/interfaces';
import { DropdownToolbarButton, hideToolbar, showToolbar, Spacer, ToolbarButton } from '../common';
import { positionInsertion, shouldShowInsertionToolbar } from './utils';

type InsertionToolbarProps = {
  isPerformingAsyncAction: boolean;
  toolbarItems: ToolbarItem[];
  commandContext: CommandContext;
};

function insertionAreEqual(prevProps: InsertionToolbarProps, nextProps: InsertionToolbarProps) {
  return (
    prevProps.commandContext === nextProps.commandContext &&
    prevProps.toolbarItems === nextProps.toolbarItems &&
    prevProps.isPerformingAsyncAction === nextProps.isPerformingAsyncAction
  );
}
export const InsertionToolbar: React.FC<InsertionToolbarProps> = React.memo((props) => {
  const { toolbarItems } = props;
  const ref = useRef();
  const editor = useSlate();
  const focused = useFocused();

  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  useEffect(() => {
    const el = ref.current as any;

    if (!el) {
      return;
    }

    const reposition = () => positionInsertion(el, editor);

    if (focused && shouldShowInsertionToolbar(editor)) {
      reposition();
      showToolbar(el);
    } else {
      hideToolbar(el);
    }

    window.addEventListener('resize', reposition);
    return () => {
      hideToolbar(el);
      window.removeEventListener('resize', reposition);
    };
  });

  return (
    <div
      style={{ display: 'none' }}
      onMouseDown={(e) => e.preventDefault()}
      ref={ref as any}
      className={classNames(['toolbar add-resource-content', isPopoverOpen ? 'active' : ''])}
    >
      <div className="insert-button-container">
        <Popover
          containerClassName="add-resource-popover"
          onClickOutside={(_e) => setIsPopoverOpen(false)}
          isOpen={isPopoverOpen}
          align="center"
          positions={['bottom']}
          content={
            <div className="hovering-toolbar">
              <div className="btn-group btn-group-vertical btn-group-sm" role="group">
                {[
                  ...toolbarItems.map((t, i) => {
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
                    // eslint-disable-next-line
                    return <DropdownToolbarButton {...shared} />;
                  }),
                ].filter((x) => x)}
              </div>
            </div>
          }
        >
          <div className="insert-button" onClick={() => setIsPopoverOpen(!isPopoverOpen)}>
            {props.isPerformingAsyncAction ? (
              <LoadingSpinner size={LoadingSpinnerSize.Normal} />
            ) : (
              <i className="fa fa-plus"></i>
            )}
          </div>
        </Popover>
      </div>
    </div>
  );
}, insertionAreEqual);
InsertionToolbar.displayName = 'InsertionToolbar';
