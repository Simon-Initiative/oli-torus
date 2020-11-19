import React from 'react';
import { connect } from 'react-redux';
import { State, Dispatch } from 'state';
import { DragHandle } from '../DragHandle';
import { EditLink } from '../../misc/EditLink';
import { ObjectivesList } from './ObjectivesList';
import { Purpose } from 'components/content/Purpose';
import { DeleteButton } from 'components/misc/DeleteButton';
import { Purpose as PurposeType, ResourceContent, ActivityReference } from 'data/content/resource';
import * as Immutable from 'immutable';
import { updatePreferences } from 'state/preferences';
import { Preferences } from 'data/persistence/preferences';
import { valueOr } from 'utils/common';
import { Maybe } from 'tsmonad';

const getDescription = (props: ActivityBlockProps) => {
  return props.previewText !== ''
    ? props.previewText
    : <i>Empty</i>;
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

  const renderLivePreview = (props: ActivityBlockProps) => (
    <div className="card-body">

      {props.children}

      <div className="activity-preview-info">
        This is a live preview of your activity.
        <button className="btn btn-xs btn-link ml-2"
          onClick={() => props.onUpdatePreferences({ live_preview_display: 'hidden' })}>
          <i className="lar la-eye-slash"></i> Hide
        </button>
      </div>
    </div>
  );

  const renderHidden = (props: ActivityBlockProps) => (
    <div className="card-body">
      <div className="activity-preview-info d-flex">
        <div className="flex-grow-1 px-4 preview-text">{props.previewText}</div>
        <button className="btn btn-xs btn-link flex-shrink-0 ml-2"
          onClick={() => props.onUpdatePreferences({ live_preview_display: 'show' })}>
          <i className="lar la-eye"></i> Live Preview
        </button>
      </div>
    </div>
  );

  return (
    <div className="resource-content-frame card">
      <div className="card-header px-2"
        draggable={props.editMode}
        onDragStart={e => props.onDragStart(e, id)}
        onDragEnd={props.onDragEnd}>
        <div className="d-flex flex-row align-items-center">

          <div className="d-flex align-items-center flex-grow-1">
            <DragHandle style={{ height: 24, marginRight: 10 }} />

            <EditLink
              label={props.label}
              href={`/project/${props.projectSlug}/resource/${props.resourceSlug}/activity/${props.contentItem.activitySlug}`} />

          </div>

          <Purpose
            purpose={props.contentItem.purpose}
            purposes={props.purposes}
            editMode={props.editMode}
            onEdit={props.onEditPurpose} />

          <DeleteButton editMode={props.content.size > 1} onClick={props.onRemove} />
        </div>
      </div>

      <ObjectivesList objectives={props.objectives} ></ObjectivesList>

      {props.preferences.caseOf({
        just: ({ live_preview_display }) => live_preview_display !== 'hidden'
          ? renderLivePreview(props)
          : renderHidden(props),
        nothing: () => renderLivePreview(props),
      })}

      <div className="reorder-mode-description">
        {getDescription(props)}
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

type OwnProps = {

};

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
