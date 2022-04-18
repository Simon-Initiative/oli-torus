import React from 'react';
import { DeleteButton } from 'components/misc/DeleteButton';
import { Purpose as PurposeType, ResourceContent, ActivityReference } from 'data/content/resource';
import * as Immutable from 'immutable';
import { Preferences } from 'data/persistence/preferences';
import { Maybe } from 'tsmonad';
import styles from './ContentBlock.modules.scss';
import { classNames } from 'utils/classNames';

interface ActivityBlockProps {
  children?: JSX.Element | JSX.Element[];
  editMode: boolean;
  content: Immutable.List<ResourceContent>;
  canRemove: boolean;
  purposes: PurposeType[];
  activity: ActivityReference;
  label: string;
  projectSlug: string;
  resourceSlug: string;
  previewText: string;
  objectives: string[];
  preferences: Maybe<Preferences>;
  onDragStart: (e: React.DragEvent<HTMLDivElement>, id: string) => void;
  onDragEnd: () => void;
  onEditPurpose: (purpose: string) => void;
  onRemove: (key: string) => void;
  onUpdatePreferences: (p: Partial<Preferences>) => any;
}

export const ActivityBlock = (props: ActivityBlockProps) => {
  return (
    <div
      id={`content-header-${props.activity.id}`}
      className={classNames(styles.activityBlock, 'activity-block')}
    >
      <div className={styles.actions}>
        <DeleteButton
          editMode={props.editMode && props.canRemove}
          onClick={() => props.onRemove(props.activity.id)}
        />
      </div>
      <div id={`block-${props.activity.id}`} className="p-2">
        {props.children}
      </div>
    </div>
  );
};
