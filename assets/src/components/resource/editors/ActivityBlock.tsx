import React from 'react';
import { connect } from 'react-redux';
import { State, Dispatch } from 'state';
import { DeleteButton } from 'components/misc/DeleteButton';
import { Purpose as PurposeType, ResourceContent, ActivityReference } from 'data/content/resource';
import * as Immutable from 'immutable';
import { updatePreferences } from 'state/preferences';
import { Preferences } from 'data/persistence/preferences';
import { valueOr } from 'utils/common';
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

const ActivityBlock = (props: ActivityBlockProps) => {
  return (
    <div className={classNames(styles.activityBlock, 'activity-block')}>
      <div className={styles.actions}>
        <DeleteButton
          editMode={props.editMode && props.canRemove}
          onClick={() => props.onRemove(props.activity.id)}
        />
      </div>
      <div id={props.activity.id} className="p-2">
        {props.children}
      </div>
    </div>
  );
};

interface StateProps {
  preferences: Maybe<Preferences>;
}

interface DispatchProps {
  onUpdatePreferences: (p: Partial<Preferences>) => any;
}

// eslint-disable-next-line
type OwnProps = {};

const mapStateToProps = (state: State, ownProps: OwnProps): StateProps => {
  const { preferences } = state.preferences;

  return {
    preferences,
  };
};

const mapDispatchToProps = (dispatch: Dispatch, ownProps: OwnProps): DispatchProps => {
  return {
    onUpdatePreferences: ({ live_preview_display }: Partial<Preferences>) =>
      dispatch(updatePreferences({ live_preview_display: valueOr(live_preview_display, null) })),
  };
};

const controller = connect<StateProps, DispatchProps, OwnProps>(
  mapStateToProps,
  mapDispatchToProps,
)(ActivityBlock);

export { controller as ActivityBlock };
