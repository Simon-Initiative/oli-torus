import React, { PropsWithChildren, useEffect, useState } from 'react';
import * as Immutable from 'immutable';
import isHotkey from 'is-hotkey';
import { throttle } from 'lodash';
import { classNames, ClassName } from 'utils/classNames';
import styles from './ContentOutline.modules.scss';
import {
  StructuredContent,
  ActivityReference,
  ResourceContent,
  ContentPurposes,
} from 'data/content/resource';
import { ActivityEditContext } from 'data/content/activity';
import { getContentDescription } from 'data/content/utils';
import { DragHandle } from 'components/resource/DragHandle';
import { focusHandler } from './dragndrop/handlers/focus';
import { moveHandler } from './dragndrop/handlers/move';
import { dragEndHandler } from './dragndrop/handlers/dragEnd';
import { dropHandler, scrollToResourceEditor } from './dragndrop/handlers/drop';
import { getDragPayload } from './dragndrop/utils';
import { dragStartHandler } from './dragndrop/handlers/dragStart';
import { DropTarget } from './dragndrop/DropTarget';
import { ActivityEditorMap } from 'data/content/editors';
import { ProjectSlug } from 'data/types';

const getActivityDescription = (activity: ActivityEditContext) => {
  return activity.model.authoring?.previewText || <i>No content</i>;
};

const getContentTitle = (item: StructuredContent) => {
  if (item.purpose === 'none') {
    return 'Paragraph';
  }

  return ContentPurposes.find((p) => p.value === item.purpose)?.label;
};

const getViewportHeight = () =>
  Math.max(document.documentElement.clientHeight || 0, window.innerHeight || 0);

const calculateOutlineHeight = () => {
  return Math.max(getViewportHeight() - 380, 220);
};

interface ContentOutlineProps {
  className?: ClassName;
  editMode: boolean;
  content: Immutable.OrderedMap<string, ResourceContent>;
  activityContexts: Immutable.Map<string, ActivityEditContext>;
  editorMap: ActivityEditorMap;
  projectSlug: ProjectSlug;
  onEditContentList: (content: Immutable.OrderedMap<string, ResourceContent>) => void;
}

export const ContentOutline = ({
  className,
  editMode,
  content,
  activityContexts,
  editorMap,
  projectSlug,
  onEditContentList,
}: ContentOutlineProps) => {
  const [activeDragId, setActiveDragId] = useState<string | null>(null);
  const [assistive, setAssistive] = useState('');
  const [height, setHeight] = useState(calculateOutlineHeight());

  // adjust the height of the content outline when the window is resized
  useEffect(() => {
    const handleResize = throttle(() => setHeight(calculateOutlineHeight()), 200);
    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
    };
  }, []);

  // register keydown handlers
  const isShiftArrowDown = isHotkey('shift+down');
  const isShiftArrowUp = isHotkey('shift+up');

  const isReorderMode = activeDragId !== null;
  const onDragEnd = dragEndHandler(setActiveDragId);
  const onDrop = dropHandler(content, onEditContentList, projectSlug, onDragEnd, editMode);

  const items = [
    ...content.entrySeq().map(([contentId, item], index) => {
      const onFocus = focusHandler(setAssistive, content, editorMap, activityContexts);
      const onMove = moveHandler(
        content,
        onEditContentList,
        editorMap,
        activityContexts,
        setAssistive,
      );

      const handleKeyDown = (e: React.KeyboardEvent<HTMLDivElement>) => {
        if (isShiftArrowDown(e.nativeEvent)) {
          onMove(contentId, false);
        } else if (isShiftArrowUp(e.nativeEvent)) {
          onMove(contentId, true);
        }
      };

      const dragPayload = getDragPayload(item, activityContexts, projectSlug);
      const onDragStart = dragStartHandler(dragPayload, item, setActiveDragId);
      const isDragging = contentId === activeDragId;

      return (
        <>
          {isReorderMode && <DropTarget id={contentId} index={index} onDrop={onDrop} />}

          <div
            className={classNames(styles.item, className, isDragging && 'is-dragging')}
            draggable={editMode}
            onDragStart={(e) => onDragStart(e, contentId)}
            onDragEnd={onDragEnd}
            onKeyDown={handleKeyDown}
            onFocus={(_e) => onFocus(contentId)}
            onClick={() => scrollToResourceEditor(contentId)}
          >
            <DragHandle style={{ margin: '10px 10px 10px 0' }} />
            {renderItem(item, activityContexts)}
          </div>
        </>
      );
    }),
    isReorderMode && <DropTarget id="last" index={content.size || 0} onDrop={onDrop} />,
  ];

  return (
    <div className={styles.contentOutlineContainer}>
      <div className={classNames(styles.contentOutline, className)} style={{ maxHeight: height }}>
        {items}
      </div>
    </div>
  );
};

const renderItem = (
  item: ResourceContent,
  activityContexts: Immutable.Map<string, ActivityEditContext>,
) => {
  switch (item.type) {
    case 'content':
      return (
        <>
          <Icon iconName="las la-paragraph" />
          <Description title={getContentTitle(item)}>{getContentDescription(item)}</Description>
        </>
      );

    case 'selection':
      return <>Selection</>;

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

    case 'group':
      return <></>;

    default:
      return <>Unknown</>;
  }
};

interface IconProps {
  iconName: string;
}

const Icon = ({ iconName }: IconProps) => (
  <div className={styles.icon}>
    <i className={iconName}></i>
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
