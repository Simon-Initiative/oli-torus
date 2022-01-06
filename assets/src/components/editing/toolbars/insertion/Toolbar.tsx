import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';
import React, { useEffect, useRef, useState } from 'react';
import { Popover } from 'react-tiny-popover';
import { Range } from 'slate';
import { ReactEditor, useFocused, useSlate, useSlateStatic } from 'slate-react';
import { classNames } from 'utils/classNames';
import guid from 'utils/guid';
import { CommandContext, ToolbarItem } from '../../commands/interfaces';
import { DropdownToolbarButton, hideToolbar, showToolbar, Spacer, ToolbarButton } from '../common';
import { positionInsertion, inEmptyLine } from './utils';

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
  const ref = useRef<HTMLDivElement>(null);
  const editor = useSlateStatic();
  const focused = useFocused();
  const id = guid();

  console.log(
    'in editor',
    'focused?',
    ReactEditor.isFocused(editor),
    'selected?',
    editor.selection && Range.isCollapsed(editor.selection),
  );

  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const reposition = () => positionInsertion(el, editor);
    if (!isPopoverOpen) {
      hideToolbar(el);
    }

    if (isPopoverOpen || (focused && inEmptyLine(editor))) {
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

  const [content, setContent] = useState(<span></span>);

  const buttons = (
    <>
      {[
        ...toolbarItems.map((t, i) => {
          if (t.type !== 'CommandDesc') {
            return <Spacer key={'spacer-' + i} />;
          }
          if (!t.command.precondition(editor)) {
            return null;
          }

          const shared = {
            style: 'btn',
            key: t.description(editor),
            icon: t.icon(editor),
            tooltip: t.description(editor),
            command: t.command,
            context: props.commandContext,
            parentElement: id,
            setParentPopoverOpen: setIsPopoverOpen,
          };

          if (t.command.obtainParameters === undefined) {
            return <ToolbarButton {...shared} />;
          }
          // eslint-disable-next-line
          return <DropdownToolbarButton {...shared} setContent={setContent} />;
        }),
      ].filter((x) => x)}
    </>
  );

  useEffect(() => {
    setContent(buttons);
  }, []);

  console.log('popover open', isPopoverOpen);
  if (!isPopoverOpen && !inEmptyLine(editor)) {
    return null;
  }

  return (
    <div
      style={{ display: 'none' }}
      ref={ref}
      id={id}
      className={classNames(['toolbar add-resource-content', isPopoverOpen ? 'active' : ''])}
    >
      <div className="insert-button-container">
        <Popover
          containerClassName="add-resource-popover"
          onClickOutside={(_e) => {
            console.log('clicked outside');
            setIsPopoverOpen(false);
            setContent(buttons);
          }}
          isOpen={isPopoverOpen}
          align="center"
          padding={5}
          reposition={false}
          positions={['right']}
          boundaryElement={document.body}
          parentElement={ref.current || undefined}
          content={
            <div className="insertion-toolbar">
              <div className="btn-group btn-group-sm" role="group">
                {content}
              </div>
            </div>
          }
        >
          <div
            className="insert-button"
            onClick={() => {
              setContent(buttons);
              setIsPopoverOpen(!isPopoverOpen);
            }}
          >
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
