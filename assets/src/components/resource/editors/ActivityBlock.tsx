import React from 'react';
import { connect } from 'react-redux';
import { State, Dispatch } from 'state';
import { DragHandle } from '../DragHandle';
import { Purpose } from 'components/content/Purpose';
import { DeleteButton } from 'components/misc/DeleteButton';
import { Purpose as PurposeType, ResourceContent, ActivityReference } from 'data/content/resource';
import * as Immutable from 'immutable';
import { updatePreferences } from 'state/preferences';
import { Preferences } from 'data/persistence/preferences';
import { valueOr } from 'utils/common';
import { Maybe } from 'tsmonad';

const getDescription = (props: ActivityBlockProps) => {
  return props.previewText !== '' ? props.previewText : <i>Empty</i>;
};

interface ActivityBlockProps {
  children?: JSX.Element | JSX.Element[];
  editMode: boolean;
  content: Immutable.List<ResourceContent>;
  purposes: PurposeType[];
  contentItem: ActivityReference;
  label: string;
  projectSlug: string;
  resourceSlug: string;
  previewText: string;
  objectives: string[];
  preferences: Maybe<Preferences>;
  onDragStart: (e: React.DragEvent<HTMLDivElement>, id: string) => void;
  onDragEnd: () => void;
  onEditPurpose: (purpose: string) => void;
  onRemove: () => void;
  onUpdatePreferences: (p: Partial<Preferences>) => any;
}

const ActivityBlock = (props: ActivityBlockProps) => {
  const id = `activity-header${props.contentItem.activitySlug}`;

  return (
    <div className="activity-block resource-content-frame card">
      <div
        className="card-header px-2"
        draggable={props.editMode}
        onDragStart={(e) => props.onDragStart(e, id)}
        onDragEnd={props.onDragEnd}
      >
        <div className="d-flex flex-row align-items-center">
          <div className="d-flex align-items-center flex-grow-1">
            <DragHandle style={{ height: 24, marginRight: 10 }} />
          </div>

          <Purpose
            purpose={props.contentItem.purpose}
            purposes={props.purposes}
            editMode={props.editMode}
            onEdit={props.onEditPurpose}
          />

          <DeleteButton editMode={props.content.size > 1} onClick={props.onRemove} />
        </div>
      </div>
      <div className="card-body">{props.children}</div>
      <div className="reorder-mode-description">{getDescription(props)}</div>
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
