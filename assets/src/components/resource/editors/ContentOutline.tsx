import React, { useEffect, useState } from 'react';
import * as Immutable from 'immutable';
import isHotkey from 'is-hotkey';
import { throttle } from 'lodash';
import { Tooltip } from 'components/common/Tooltip';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityEditorMap } from 'data/content/editors';
import {
  ActivityReference,
  ResourceContent,
  ResourceGroup,
  canInsert,
} from 'data/content/resource';
import { PageEditorContent } from 'data/editor/PageEditorContent';
import { ProjectSlug } from 'data/types';
import { getViewportHeight } from 'utils/browser';
import { ClassName, classNames } from 'utils/classNames';
import { useStateFromLocalStorage } from 'utils/useStateFromLocalStorage';
import { SelectionOutlineItem } from './ActivityBankSelectionEditor';
import { ActivityEditorContentOutlineItem } from './ActivityEditor';
import { AlternativeOutlineItem, AlternativesOutlineItem } from './AlternativesEditor';
import { ContentBreakOutlineItem } from './ContentBreak';
import { ContentOutlineItem } from './ContentEditor';
import styles from './ContentOutline.modules.scss';
import { LTIExternalToolOutlineItem } from './LtiExternalToolEditor';
import { OutlineItemError, UnknownItem } from './OutlineItem';
import { PurposeGroupOutlineItem } from './PurposeGroupEditor';
import { SurveyOutlineItem } from './SurveyEditor';
import { DropTarget } from './dragndrop/DropTarget';
import { dragEndHandler } from './dragndrop/handlers/dragEnd';
import { dragStartHandler } from './dragndrop/handlers/dragStart';
import { dropHandler } from './dragndrop/handlers/drop';
import { focusHandler } from './dragndrop/handlers/focus';
import { moveHandler } from './dragndrop/handlers/move';
import { getDragPayload } from './dragndrop/utils';

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

        const onKeyDown = (id: string) => (e: React.KeyboardEvent<HTMLDivElement>) => {
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
            assistive={assistive}
            contentItem={contentItem}
            activityContexts={activityContexts}
            isReorderMode={isReorderMode}
            activeDragIndex={activeDragIndex}
            parentDropIndex={[]}
            content={content}
            collapsedGroupMap={collapsedGroupMap}
            setCollapsedGroupMap={setCollapsedGroupMap}
            onEditContent={onEditContent}
            onFocus={onFocus}
            onKeyDown={onKeyDown}
          />
        );
      }),
    isReorderMode && (
      <DropTarget key="last" id="last" index={[content.model.size + 1]} onDrop={onDropLast} />
    ),
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
            <Tooltip title="Open Sidebar" placement="right">
              <button
                className={classNames(styles.contentOutlineToggleButton)}
                onClick={() => setShowOutline(true)}
              >
                <i className="fa fa-angle-right"></i>
              </button>
            </Tooltip>
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
  onKeyDown: (id: string) => React.KeyboardEventHandler<HTMLDivElement>;
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
  onKeyDown,
  onFocus,
  setCollapsedGroupMap,
}: OutlineItemProps): JSX.Element => {
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

  const expanded = !collapsedGroupMap.get(id);
  const toggleCollapsibleGroup = (id: string) =>
    setCollapsedGroupMap(collapsedGroupMap.set(id, expanded));

  const props = {
    className,
    id,
    level,
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
    collapsedGroupMap,
    canDropHere,
    dropIndex,
    expanded,
    toggleCollapsibleGroup,
    onEditContent,
    setActiveDragId,
    onFocus,
    setCollapsedGroupMap,
    onDragStart,
    onDragEnd,
    onDrop,
    onDropLast,
    onKeyDown,
  };

  switch (contentItem.type) {
    // ResourceContent types
    case 'content':
      return <ContentOutlineItem {...props} contentItem={contentItem} />;

    case 'break':
      return <ContentBreakOutlineItem {...props} />;

    case 'selection':
      return <SelectionOutlineItem {...props} contentItem={contentItem} />;

    case 'activity-reference':
      const activity = props.activityContexts.get(
        (props.contentItem as ActivityReference).activitySlug,
      );

      if (activity) {
        return <ActivityEditorContentOutlineItem {...props} activity={activity} />;
      } else {
        return <OutlineItemError />;
      }

    // ResourceGroup types
    case 'group':
      return (
        <ResourceGroupItem {...props} contentItem={contentItem}>
          <PurposeGroupOutlineItem {...props} contentItem={contentItem} />
        </ResourceGroupItem>
      );

    case 'survey':
      return (
        <ResourceGroupItem {...props} contentItem={contentItem}>
          <SurveyOutlineItem {...props} contentItem={contentItem} />
        </ResourceGroupItem>
      );

    case 'alternatives':
      return (
        <ResourceGroupItem {...props} contentItem={contentItem}>
          <AlternativesOutlineItem {...props} contentItem={contentItem} />
        </ResourceGroupItem>
      );

    case 'alternative':
      return (
        <ResourceGroupItem {...props} contentItem={contentItem}>
          <AlternativeOutlineItem {...props} contentItem={contentItem} />
        </ResourceGroupItem>
      );

    case 'lti-external-tool':
      return <LTIExternalToolOutlineItem {...props} contentItem={contentItem} />;

    default:
      return <UnknownItem />;
  }
};

type ResourceGroupItemProps = {
  className?: ClassName;
  id: string;
  level: number;
  parents: ResourceContent[];
  editMode: boolean;
  projectSlug: string;
  activeDragId: string | null;
  assistive: string;
  contentItem: ResourceGroup;
  activityContexts: Immutable.Map<string, ActivityEditContext>;
  isReorderMode: boolean;
  activeDragIndex: number[];
  content: PageEditorContent;
  collapsedGroupMap: Immutable.Map<string, boolean>;
  canDropHere: boolean;
  dropIndex: number[];
  children: React.ReactNode;
  expanded: boolean;
  toggleCollapsibleGroup: (id: string) => void;
  onEditContent: (content: PageEditorContent) => void;
  setActiveDragId: (id: string) => void;
  onFocus: (id: string) => void;
  setCollapsedGroupMap: (map: Immutable.Map<string, boolean>) => void;
  onDrop: (e: React.DragEvent<HTMLDivElement>, index: number[]) => void;
  onDropLast: (e: React.DragEvent<HTMLDivElement>, index: number[]) => void;
  onKeyDown: (id: string) => React.KeyboardEventHandler<HTMLDivElement>;
};

const ResourceGroupItem = ({
  className,
  id,
  level,
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
  collapsedGroupMap,
  canDropHere,
  dropIndex,
  children,
  expanded,
  onEditContent,
  setActiveDragId,
  onFocus,
  setCollapsedGroupMap,
  onDrop,
  onDropLast,
  onKeyDown,
}: ResourceGroupItemProps) => {
  return (
    <>
      {isReorderMode && canDropHere && (
        <DropTarget key={`drop-target-${id}`} id={id} index={dropIndex} onDrop={onDrop} />
      )}

      <div className={classNames(styles.group, className)}>
        {children}

        {expanded && (
          <div className={styles.groupedOutline}>
            {contentItem.children
              .filter((containerItem: ResourceContent) => containerItem.id !== activeDragId)
              .map((c, i) => {
                return (
                  <OutlineItem
                    key={c.id}
                    className={className}
                    id={c.id}
                    level={level + 1}
                    index={i}
                    parents={[...parents, contentItem]}
                    editMode={editMode}
                    projectSlug={projectSlug}
                    activeDragId={activeDragId}
                    setActiveDragId={setActiveDragId}
                    onKeyDown={onKeyDown}
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
            {isReorderMode && canDrop(activeDragId, [...parents, contentItem], content) && (
              <DropTarget
                key="last"
                id="last"
                index={[...dropIndex, contentItem.children.size]}
                onDrop={onDropLast}
              />
            )}
          </div>
        )}
      </div>
    </>
  );
};

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
