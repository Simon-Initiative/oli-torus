import React, { PropsWithChildren, useEffect, useState } from 'react';
import * as Immutable from 'immutable';
import isHotkey from 'is-hotkey';
import { throttle } from 'lodash';
import { classNames, ClassName } from 'utils/classNames';
import styles from './ContentOutline.modules.scss';
import {
  ActivityReference,
  ResourceContent,
  PurposeTypes,
  NestableContainer,
  isNestableContainer,
  canInsert,
} from 'data/content/resource';
import { PageEditorContent } from 'data/editor/PageEditorContent';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityBankSelection } from 'data/content/resource';
import { getContentDescription } from 'data/content/utils';
import { DragHandle } from 'components/resource/DragHandle';
import { focusHandler } from './dragndrop/handlers/focus';
import { moveHandler } from './dragndrop/handlers/move';
import { dragEndHandler } from './dragndrop/handlers/dragEnd';
import { dropHandler } from './dragndrop/handlers/drop';
import { scrollToResourceEditor } from './dragndrop/utils';
import { getDragPayload } from './dragndrop/utils';
import { dragStartHandler } from './dragndrop/handlers/dragStart';
import { DropTarget } from './dragndrop/DropTarget';
import { ActivityEditorMap } from 'data/content/editors';
import { ProjectSlug } from 'data/types';
import { getViewportHeight } from 'utils/browser';
import { useStateFromLocalStorage } from 'utils/useStateFromLocalStorage';

const getActivityDescription = (activity: ActivityEditContext) => {
  return activity.model.authoring?.previewText || <i>No content</i>;
};

const getActivitySelectionTitle = (_selection: ActivityBankSelection) => {
  return 'Activity Bank Selection';
};

const getActivitySelectionDescription = (selection: ActivityBankSelection) => {
  return `${selection.count} selection${selection.count > 1 ? 's' : ''}`;
};

const calculateOutlineHeight = (scrollOffset: number) => {
  const topMargin = 420;
  const scrolledMargin = 200;
  const minHeight = 220;
  const scrollCompensation = Math.max(topMargin - scrollOffset, scrolledMargin);
  return Math.max(getViewportHeight() - scrollCompensation, minHeight);
};

interface ContentOutlineProps {
  className?: ClassName;
  editMode: boolean;
  content: PageEditorContent;
  activityContexts: Immutable.Map<string, ActivityEditContext>;
  editorMap: ActivityEditorMap;
  projectSlug: ProjectSlug;
  resourceSlug: ProjectSlug;
  onEditContent: (content: PageEditorContent) => void;
}

export const ContentOutline = ({
  className,
  editMode,
  content,
  activityContexts,
  editorMap,
  projectSlug,
  resourceSlug,
  onEditContent,
}: ContentOutlineProps) => {
  const [activeDragId, setActiveDragId] = useState<string | null>(null);
  const [assistive, setAssistive] = useState('');
  const [scrollPos, setScrollPos] = useState(0);
  const [height, setHeight] = useState(calculateOutlineHeight(scrollPos));
  const [showOutline, setShowOutline] = useStateFromLocalStorage(false, 'editorShowOutline');
  const [collapsedGroupMap, setCollapsedGroupMap] = useStateFromLocalStorage(
    Immutable.Map<string, boolean>(),
    `editorCollapsedGroupMap-${resourceSlug}`,
  );

  // adjust the height of the content outline when the window is resized
  useEffect(() => {
    const handleResize = throttle(() => setHeight(calculateOutlineHeight(scrollPos)), 200);
    window.addEventListener('resize', handleResize);

    const handleScroll = throttle(() => {
      setScrollPos(document.documentElement.scrollTop);
      setHeight(calculateOutlineHeight(document.documentElement.scrollTop));
    }, 200);
    document.addEventListener('scroll', handleScroll);

    return () => {
      window.removeEventListener('resize', handleResize);
      window.removeEventListener('scroll', handleScroll);
    };
  }, [scrollPos]);

  // register keydown handlers
  const isShiftArrowDown = isHotkey('shift+down');
  const isShiftArrowUp = isHotkey('shift+up');

  const isReorderMode = activeDragId !== null;
  const activeDragIndex = content.findIndex((c: ResourceContent) => c.id == activeDragId);
  const onDropLast = dropHandler(
    content,
    onEditContent,
    projectSlug,
    dragEndHandler(setActiveDragId),
    editMode,
  );

  const items = [
    ...content.model
      .filter((contentItem: ResourceContent) => contentItem.id !== activeDragId)
      .map((contentItem: ResourceContent, index: number) => {
        const onFocus = focusHandler(setAssistive, content, editorMap, activityContexts);
        const onMove = moveHandler(
          content,
          onEditContent,
          editorMap,
          activityContexts,
          setAssistive,
        );

        const handleKeyDown = (id: string) => (e: React.KeyboardEvent<HTMLDivElement>) => {
          if (isShiftArrowDown(e.nativeEvent)) {
            onMove(id, false);
            setTimeout(() => document.getElementById(`content-item-${id}`)?.focus());
          } else if (isShiftArrowUp(e.nativeEvent)) {
            onMove(id, true);
            setTimeout(() => document.getElementById(`content-item-${id}`)?.focus());
          }
        };

        return (
          <OutlineItem
            key={contentItem.id}
            id={contentItem.id}
            index={index}
            parents={[]}
            className={className}
            level={0}
            editMode={editMode}
            projectSlug={projectSlug}
            activeDragId={activeDragId}
            setActiveDragId={setActiveDragId}
            handleKeyDown={handleKeyDown}
            onFocus={onFocus}
            assistive={assistive}
            contentItem={contentItem}
            activityContexts={activityContexts}
            isReorderMode={isReorderMode}
            activeDragIndex={activeDragIndex}
            parentDropIndex={[]}
            content={content}
            onEditContent={onEditContent}
            collapsedGroupMap={collapsedGroupMap}
            setCollapsedGroupMap={setCollapsedGroupMap}
          />
        );
      }),
    isReorderMode && <DropTarget id="last" index={[content.model.size + 1]} onDrop={onDropLast} />,
  ];

  return (
    <div
      className={classNames(
        styles.contentOutlineContainer,
        showOutline && styles.contentOutlineContainerShow,
      )}
    >
      {showOutline ? (
        <div className={classNames(styles.contentOutline, className)}>
          <ContentOutlineToolbar onHideOutline={() => setShowOutline(false)} />
          <div
            className={classNames(
              styles.contentOutlineItems,
              isReorderMode && styles.contentOutlineItemsReorderMode,
            )}
            style={{ maxHeight: height }}
          >
            {items}
          </div>
        </div>
      ) : (
        <div className={styles.contentOutlineToggleSticky}>
          <div className={styles.contentOutlineToggle}>
            <button
              className={classNames(styles.contentOutlineToggleButton)}
              onClick={() => setShowOutline(true)}
            >
              <i className="fa fa-angle-right"></i>
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

type OutlineItemProps = {
  className?: ClassName;
  id: string;
  level: number;
  index: number;
  parents: ResourceContent[];
  editMode: boolean;
  projectSlug: string;
  activeDragId: string | null;
  assistive: string;
  contentItem: ResourceContent;
  activityContexts: Immutable.Map<string, ActivityEditContext>;
  isReorderMode: boolean;
  activeDragIndex: number[];
  parentDropIndex: number[];
  content: PageEditorContent;
  collapsedGroupMap: Immutable.Map<string, boolean>;
  onEditContent: (content: PageEditorContent) => void;
  setActiveDragId: (id: string) => void;
  handleKeyDown: (id: string) => React.KeyboardEventHandler<HTMLDivElement>;
  onFocus: (id: string) => void;
  setCollapsedGroupMap: (map: Immutable.Map<string, boolean>) => void;
};

const OutlineItem = ({
  className,
  id,
  level,
  index,
  parents,
  editMode,
  projectSlug,
  activeDragId,
  assistive,
  content,
  contentItem,
  activityContexts,
  isReorderMode,
  activeDragIndex,
  parentDropIndex,
  collapsedGroupMap,
  onEditContent,
  setActiveDragId,
  handleKeyDown,
  onFocus,
  setCollapsedGroupMap,
}: OutlineItemProps) => {
  const dragPayload = getDragPayload(contentItem, activityContexts, projectSlug);
  const onDragStart = dragStartHandler(dragPayload, contentItem, setActiveDragId);
  const onDragEnd = dragEndHandler(setActiveDragId);
  const onDrop = dropHandler(content, onEditContent, projectSlug, onDragEnd, editMode);
  const onDropLast = dropHandler(
    content,
    onEditContent,
    projectSlug,
    dragEndHandler(setActiveDragId),
    editMode,
  );

  // adjust for the fact that the item being dragged is filtered out of the rendered elements
  const dropIndex =
    index >= activeDragIndex[level] ? [...parentDropIndex, index + 1] : [...parentDropIndex, index];
  const canDropHere = canDrop(activeDragId, parents, content);

  if (isNestableContainer(contentItem)) {
    const containerItem = contentItem as NestableContainer;

    const expanded = !collapsedGroupMap.get(id);
    const toggleCollapsableGroup = (id: string) =>
      setCollapsedGroupMap(collapsedGroupMap.set(id, expanded));

    const icon =
      contentItem.type === 'survey' ? (
        <Icon iconName="las la-poll" />
      ) : (
        <ExpandToggle expanded={expanded} onClick={() => toggleCollapsableGroup(id)} />
      );

    return (
      <>
        {isReorderMode && canDropHere && <DropTarget id={id} index={dropIndex} onDrop={onDrop} />}

        <div id={`content-item-${id}`} className={classNames(styles.group, className)}>
          <div
            className={classNames(styles.groupLink, !expanded && 'mb-1')}
            onClick={(e) =>
              // only scroll to the resource editor if this event was not a expand toggle event
              !(e as any).isExpandToggleEvent ? scrollToResourceEditor(id) : undefined
            }
            role="button"
            draggable={editMode}
            tabIndex={0}
            onDragStart={(e) => onDragStart(e, id)}
            onDragEnd={onDragEnd}
            onKeyDown={handleKeyDown(id)}
            onFocus={(_e) => onFocus(id)}
            aria-label={assistive}
          >
            <DragHandle style={{ margin: '10px 10px 10px 0' }} />
            {icon}
            <Description title={getContainerTitle(containerItem)}>
              {containerItem.children.size} items
            </Description>
          </div>
          {expanded && (
            <div className={styles.groupedOutline}>
              {containerItem.children
                .filter((containerItem: ResourceContent) => containerItem.id !== activeDragId)
                .map((c, i) => {
                  return (
                    <OutlineItem
                      key={id}
                      className={className}
                      id={c.id}
                      level={level + 1}
                      index={i}
                      parents={[...parents, containerItem]}
                      editMode={editMode}
                      projectSlug={projectSlug}
                      activeDragId={activeDragId}
                      setActiveDragId={setActiveDragId}
                      handleKeyDown={handleKeyDown}
                      onFocus={onFocus}
                      assistive={assistive}
                      contentItem={c}
                      activityContexts={activityContexts}
                      isReorderMode={isReorderMode}
                      activeDragIndex={activeDragIndex}
                      parentDropIndex={dropIndex}
                      content={content}
                      onEditContent={onEditContent}
                      collapsedGroupMap={collapsedGroupMap}
                      setCollapsedGroupMap={setCollapsedGroupMap}
                    />
                  );
                })}
              {isReorderMode && canDrop(activeDragId, [...parents, containerItem], content) && (
                <DropTarget
                  id="last"
                  index={[...dropIndex, containerItem.children.size]}
                  onDrop={onDropLast}
                />
              )}
            </div>
          )}
        </div>
      </>
    );
  }

  if (contentItem.type === 'break') {
    return (
      <>
        {isReorderMode && canDropHere && <DropTarget id={id} index={dropIndex} onDrop={onDrop} />}

        <div
          id={`content-item-${id}`}
          className={classNames(styles.item, styles.contentBreak, className)}
          onClick={() => scrollToResourceEditor(id)}
          draggable={editMode}
          tabIndex={0}
          onDragStart={(e) => onDragStart(e, id)}
          onDragEnd={onDragEnd}
          onKeyDown={handleKeyDown(id)}
          onFocus={(_e) => onFocus(id)}
          aria-label={assistive}
        >
          <div
            className={styles.contentLink}
            onClick={() => scrollToResourceEditor(id)}
            role="button"
          >
            <div className={styles.contentBreakDashed}></div>
            <div className={styles.contentBreakLabel}>CONTENT BREAK</div>
            <div className={styles.contentBreakDashed}></div>
          </div>
        </div>
      </>
    );
  }

  return (
    <>
      {isReorderMode && canDropHere && <DropTarget id={id} index={dropIndex} onDrop={onDrop} />}

      <div
        id={`content-item-${id}`}
        className={classNames(styles.item, className)}
        onClick={() => scrollToResourceEditor(id)}
        draggable={editMode}
        tabIndex={0}
        onDragStart={(e) => onDragStart(e, id)}
        onDragEnd={onDragEnd}
        onKeyDown={handleKeyDown(id)}
        onFocus={(_e) => onFocus(id)}
        aria-label={assistive}
      >
        <DragHandle style={{ margin: '10px 10px 10px 0' }} />
        <div
          className={styles.contentLink}
          onClick={() => scrollToResourceEditor(id)}
          role="button"
        >
          {renderItem(id, contentItem, activityContexts)}
        </div>
      </div>
    </>
  );
};

const renderItem = (
  id: string,
  item: ResourceContent,
  activityContexts: Immutable.Map<string, ActivityEditContext>,
) => {
  switch (item.type) {
    case 'content':
      return (
        <>
          <Icon iconName="las la-paragraph" />
          <Description title="Paragraph">{getContentDescription(item)}</Description>
        </>
      );

    case 'selection':
      return (
        <>
          <Icon iconName="las la-cogs" />
          <Description title={getActivitySelectionTitle(item)}>
            {getActivitySelectionDescription(item)}
          </Description>
        </>
      );

    case 'activity-reference':
      const activity = activityContexts.get((item as ActivityReference).activitySlug);

      if (activity) {
        return (
          <>
            <Icon iconName="las la-shapes" />
            <Description title={activity?.title}>{getActivityDescription(activity)}</Description>
          </>
        );
      } else {
        return <div className="text-danger">An Unknown Error Occurred</div>;
      }

    default:
      return <>Unknown</>;
  }
};

function getContainerTitle(contentItem: NestableContainer) {
  if (contentItem.type === 'group') {
    switch (contentItem.purpose) {
      case 'none':
        return 'Group';
      default:
        return PurposeTypes.find(({ value }) => value === contentItem.purpose)?.label;
    }
  } else if (contentItem.type === 'survey') {
    return contentItem.title ?? 'Survey';
  }
}

function canDrop(
  activeDragId: string | null,
  parents: ResourceContent[],
  content: PageEditorContent,
): boolean {
  const activeDragItem = activeDragId && content.find(activeDragId);
  return activeDragItem ? canInsert(activeDragItem, parents) : false;
}

interface ContentOutlineToolbarProps {
  onHideOutline: () => void;
}

const ContentOutlineToolbar = ({ onHideOutline }: ContentOutlineToolbarProps) => (
  <div className={styles.toolbar}>
    <button className={classNames(styles.toolbarButton)} onClick={onHideOutline}>
      <i className="fa fa-angle-left"></i>
    </button>
  </div>
);

interface IconProps {
  iconName: string;
}

const Icon = ({ iconName }: IconProps) => (
  <div className={styles.icon}>
    <i className={classNames(iconName, 'la-lg')}></i>
  </div>
);

interface ExpandToggleProps {
  expanded: boolean;
  onClick: () => void;
}

const ExpandToggle = ({ expanded, onClick }: ExpandToggleProps) => (
  <div
    className={styles.expandToggle}
    onClick={(e) => {
      (e as any).isExpandToggleEvent = true;
      onClick();
    }}
  >
    {expanded ? <i className="las la-chevron-down"></i> : <i className="las la-chevron-right"></i>}
  </div>
);

interface DescriptionProps {
  title?: string;
}

const Description = ({ title, children }: PropsWithChildren<DescriptionProps>) => (
  <div className={styles.description}>
    <div className={styles.title}>{title}</div>
    <div className={styles.descriptionContent}>{children}</div>
  </div>
);
