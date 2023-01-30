import React, { PropsWithChildren, useRef } from 'react';
import * as Immutable from 'immutable';
import { ClassName, classNames } from 'utils/classNames';
import { PurposeTypes, ResourceGroup, ResourceContent } from 'data/content/resource';
import styles from './ContentOutline.modules.scss';
import { DropTarget } from './dragndrop/DropTarget';
import { scrollToResourceEditor } from './dragndrop/utils';
import { DragHandle } from '../DragHandle';
import { ActivityEditContext } from 'data/content/activity';

export interface OutlineItemProps {
  className?: ClassName;
  id: string;
  editMode: boolean;
  projectSlug: string;
  activeDragId: string | null;
  assistive: string;
  contentItem: ResourceContent;
  activityContexts: Immutable.Map<string, ActivityEditContext>;
  isReorderMode: boolean;
  canDropHere: boolean;
  dropIndex: number[];
  onFocus: (id: string) => void;
  onDragStart: (e: React.DragEvent<HTMLDivElement>, id: string) => void;
  onDragEnd: () => void;
  onDrop: (e: React.DragEvent<HTMLDivElement>, index: number[]) => void;
  onKeyDown: (id: string) => React.KeyboardEventHandler<HTMLDivElement>;
}

export const OutlineItem = ({
  className,
  id,
  editMode,
  assistive,
  isReorderMode,
  canDropHere,
  dropIndex,
  children,
  onFocus,
  onDragStart,
  onDragEnd,
  onDrop,
  onKeyDown,
}: PropsWithChildren<OutlineItemProps>) => {
  const ref = useRef<HTMLDivElement>(null);

  // react prop onDragEnd doesn't seem to work correctly so here we
  // manually set the dragstart handler to listen for dragend event
  // so we can properly trigger the necessary callback
  const dragStartHandler: React.DragEventHandler<HTMLDivElement> = (e) => {
    const dragEndListener = () => {
      ref.current?.removeEventListener('dragend', dragEndListener);
      onDragEnd();
    };

    ref.current?.addEventListener('dragend', dragEndListener);
    onDragStart(e, id);
  };

  const maybeScrollToEditor: React.MouseEventHandler<HTMLDivElement> = (e) =>
    // only scroll to the resource editor if this event was not a expand toggle event
    !(e as any).isExpandToggleEvent ? scrollToResourceEditor(id) : undefined;

  return (
    <>
      {isReorderMode && canDropHere && (
        <DropTarget key={`drop-target-${id}`} id={id} index={dropIndex} onDrop={onDrop} />
      )}

      <div
        ref={ref}
        key={`content-item-${id}`}
        id={`content-item-${id}`}
        className={classNames(styles.item, className)}
        onClick={maybeScrollToEditor}
        draggable={editMode}
        tabIndex={0}
        onDragStart={dragStartHandler}
        onKeyDown={onKeyDown(id)}
        onFocus={(_e) => onFocus(id)}
        aria-label={assistive}
      >
        <DragHandle style={{ margin: '10px 10px 10px 0' }} />
        <div className={styles.contentLink} onClick={maybeScrollToEditor} role="button">
          {children}
        </div>
      </div>
    </>
  );
};

export interface OutlineGroupProps {
  className?: ClassName;
  id: string;
  editMode: boolean;
  projectSlug: string;
  activeDragId: string | null;
  assistive: string;
  contentItem: ResourceContent;
  activityContexts: Immutable.Map<string, ActivityEditContext>;
  isReorderMode: boolean;
  canDropHere: boolean;
  dropIndex: number[];
  expanded: boolean;
  onFocus: (id: string) => void;
  onDragStart: (e: React.DragEvent<HTMLDivElement>, id: string) => void;
  onDragEnd: () => void;
  onDrop: (e: React.DragEvent<HTMLDivElement>, index: number[]) => void;
  onKeyDown: (id: string) => React.KeyboardEventHandler<HTMLDivElement>;
}

export const OutlineGroup = ({
  id,
  editMode,
  assistive,
  isReorderMode,
  canDropHere,
  dropIndex,
  expanded,
  children,
  onFocus,
  onDragStart,
  onDragEnd,
  onDrop,
  onKeyDown,
}: PropsWithChildren<OutlineGroupProps>) => {
  const ref = useRef<HTMLDivElement>(null);

  // react prop onDragEnd doesn't seem to work correctly so here we
  // manually set the dragstart handler to listen for dragend event
  // so we can properly trigger the necessary callback
  const dragStartHandler: React.DragEventHandler<HTMLDivElement> = (e) => {
    const dragEndListener = () => {
      ref.current?.removeEventListener('dragend', dragEndListener);
      onDragEnd();
    };

    ref.current?.addEventListener('dragend', dragEndListener);
    onDragStart(e, id);
  };

  const maybeScrollToEditor: React.MouseEventHandler<HTMLDivElement> = (e) =>
    // only scroll to the resource editor if this event was not a expand toggle event
    !(e as any).isExpandToggleEvent ? scrollToResourceEditor(id) : undefined;

  return (
    <>
      {isReorderMode && canDropHere && (
        <DropTarget key={`drop-target-${id}`} id={id} index={dropIndex} onDrop={onDrop} />
      )}

      <div
        ref={ref}
        key={`content-item-${id}`}
        className={classNames(styles.groupContainer, !expanded && 'mb-1')}
        onClick={maybeScrollToEditor}
        role="button"
        draggable={editMode}
        tabIndex={0}
        onDragStart={dragStartHandler}
        onDragEnd={onDragEnd}
        onKeyDown={onKeyDown(id)}
        onFocus={(_e) => onFocus(id)}
        aria-label={assistive}
      >
        <DragHandle style={{ margin: '10px 10px 10px 0' }} />
        <div className={styles.groupLink} onClick={maybeScrollToEditor} role="button">
          {children}
        </div>
      </div>
    </>
  );
};

interface IconProps {
  iconName: string;
}

export const Icon = ({ iconName }: IconProps) => (
  <div className={styles.icon}>
    <i className={classNames(iconName, 'la-lg')}></i>
  </div>
);

interface ExpandToggleProps {
  expanded: boolean;
  onClick: () => void;
}

export const ExpandToggle = ({ expanded, onClick }: ExpandToggleProps) => (
  <div
    className={styles.expandToggle}
    onClick={(e) => {
      (e as any).isExpandToggleEvent = true;
      onClick();
    }}
  >
    {expanded ? <i className="fas fa-chevron-down"></i> : <i className="fas fa-chevron-right"></i>}
  </div>
);

interface DescriptionProps {
  title?: React.ReactNode;
}

export const Description = ({ title, children }: PropsWithChildren<DescriptionProps>) => (
  <div className={styles.description}>
    <div className={styles.title}>{title}</div>
    <div className={styles.descriptionContent}>{children}</div>
  </div>
);

export const UnknownItem = () => <div>Unknown</div>;

export const OutlineItemError = () => <div className="text-danger">An Unknown Error Occurred</div>;

export const resourceGroupTitle = (contentItem: ResourceGroup) => {
  if (contentItem.type === 'group') {
    switch (contentItem.purpose) {
      case 'none':
        return 'Group';
      default:
        return PurposeTypes.find(({ value }) => value === contentItem.purpose)?.label;
    }
  } else if (contentItem.type === 'survey') {
    return contentItem.title ?? 'Survey';
  } else if (contentItem.type === 'alternatives') {
    return 'Alternative Content';
  }
};
