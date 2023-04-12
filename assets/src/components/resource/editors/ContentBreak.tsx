import styles from './ContentBreak.modules.scss';
import { OutlineItemProps } from './OutlineItem';
import { DropTarget } from './dragndrop/DropTarget';
import { scrollToResourceEditor } from './dragndrop/utils';
import { DeleteButton } from 'components/misc/DeleteButton';
import { Break } from 'data/content/resource';
import * as React from 'react';
import { classNames } from 'utils/classNames';

interface ContentBreakProps {
  editMode: boolean;
  contentItem: Break;
  onRemove: (key: string) => void;
}

export const ContentBreakEditor = (props: ContentBreakProps) => {
  return (
    <div id={`resource-editor-${props.contentItem.id}`} className={classNames(styles.contentBreak)}>
      <div className={styles.actions}>
        <DeleteButton
          editMode={props.editMode}
          onClick={() => props.onRemove(props.contentItem.id)}
        />
      </div>
      <div className={styles.dashed}></div>
      <div className={styles.label}>CONTENT BREAK</div>
      <div className={styles.dashed}></div>
    </div>
  );
};

interface ContentBreakOutlineItemProps extends OutlineItemProps {}

export const ContentBreakOutlineItem = (props: ContentBreakOutlineItemProps) => {
  const {
    className,
    id,
    editMode,
    assistive,
    isReorderMode,
    canDropHere,
    dropIndex,
    onFocus,
    onDragStart,
    onDragEnd,
    onDrop,
    onKeyDown,
  } = props;

  return (
    <>
      {isReorderMode && canDropHere && <DropTarget id={id} index={dropIndex} onDrop={onDrop} />}

      <div
        id={`content-item-${id}`}
        className={classNames(styles.item, styles.contentBreakOutline, className)}
        onClick={() => scrollToResourceEditor(id)}
        draggable={editMode}
        tabIndex={0}
        onDragStart={(e) => onDragStart(e, id)}
        onDragEnd={onDragEnd}
        onKeyDown={onKeyDown(id)}
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
};
