import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';
import React, { useEffect, useRef, useState } from 'react';
import { ArrowContainer, Popover } from 'react-tiny-popover';
import { useFocused, useSlate } from 'slate-react';
import { classNames } from 'utils/classNames';
import guid from 'utils/guid';
import { DropdownToolbarButton, hideToolbar, showToolbar, Spacer, ToolbarButton } from '../common';
import { positionInsertion, shouldShowInsertionToolbar } from './utils';
function insertionAreEqual(prevProps, nextProps) {
    return (prevProps.commandContext === nextProps.commandContext &&
        prevProps.toolbarItems === nextProps.toolbarItems &&
        prevProps.isPerformingAsyncAction === nextProps.isPerformingAsyncAction);
}
export const InsertionToolbar = React.memo((props) => {
    const { toolbarItems } = props;
    const ref = useRef(null);
    const editor = useSlate();
    const focused = useFocused();
    const id = guid();
    const [isPopoverOpen, setIsPopoverOpen] = useState(false);
    useEffect(() => {
        const el = ref.current;
        if (!el)
            return;
        const reposition = () => positionInsertion(el, editor);
        if (!isPopoverOpen) {
            hideToolbar(el);
        }
        if (isPopoverOpen || (focused && shouldShowInsertionToolbar(editor))) {
            reposition();
            showToolbar(el);
        }
        else {
            hideToolbar(el);
        }
        window.addEventListener('resize', reposition);
        return () => {
            hideToolbar(el);
            window.removeEventListener('resize', reposition);
        };
    });
    if (!isPopoverOpen && !shouldShowInsertionToolbar(editor)) {
        return null;
    }
    return (<div style={{ display: 'none' }} ref={ref} id={id} className={classNames(['toolbar add-resource-content', isPopoverOpen ? 'active' : ''])}>
      <div className="insert-button-container">
        <Popover containerClassName="add-resource-popover" onClickOutside={(_e) => setIsPopoverOpen(false)} isOpen={isPopoverOpen} align="center" padding={5} reposition={false} positions={['top']} boundaryElement={document.body} parentElement={ref.current || undefined} content={({ position, childRect, popoverRect }) => (<ArrowContainer position={position} childRect={childRect} popoverRect={popoverRect} arrowSize={8} arrowColor="rgb(38,38,37)" 
        // Position the arrow in the middle of the popover
        arrowStyle={{ left: popoverRect.width / 2 - 8 }}>
              <div className="hovering-toolbar">
                <div className="btn-group btn-group-vertical btn-group-sm" role="group">
                  {[
                ...toolbarItems.map((t, i) => {
                    if (t.type !== 'CommandDesc') {
                        return <Spacer key={'spacer-' + i}/>;
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
                        parentElement: id,
                        setParentPopoverOpen: setIsPopoverOpen,
                    };
                    if (t.command.obtainParameters === undefined) {
                        return <ToolbarButton {...shared}/>;
                    }
                    // eslint-disable-next-line
                    return <DropdownToolbarButton {...shared}/>;
                }),
            ].filter((x) => x)}
                </div>
              </div>
            </ArrowContainer>)}>
          <div className="insert-button" onClick={() => setIsPopoverOpen(!isPopoverOpen)}>
            {props.isPerformingAsyncAction ? (<LoadingSpinner size={LoadingSpinnerSize.Normal}/>) : (<i className="fa fa-plus"></i>)}
          </div>
        </Popover>
      </div>
    </div>);
}, insertionAreEqual);
InsertionToolbar.displayName = 'InsertionToolbar';
//# sourceMappingURL=Toolbar.jsx.map