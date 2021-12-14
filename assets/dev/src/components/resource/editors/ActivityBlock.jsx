import React from 'react';
import { connect } from 'react-redux';
import { DragHandle } from '../DragHandle';
import { Purpose } from 'components/content/Purpose';
import { DeleteButton } from 'components/misc/DeleteButton';
import { updatePreferences } from 'state/preferences';
import { valueOr } from 'utils/common';
const getDescription = (props) => {
    return props.previewText !== '' ? props.previewText : <i>Empty</i>;
};
const ActivityBlock = (props) => {
    const id = `activity-header${props.contentItem.activitySlug}`;
    return (<div className="activity-block resource-content-frame card">
      <div className="card-header px-2" draggable={props.editMode} onDragStart={(e) => props.onDragStart(e, id)} onDragEnd={props.onDragEnd}>
        <div className="d-flex flex-row align-items-center">
          <div className="d-flex align-items-center flex-grow-1">
            <DragHandle style={{ height: 24, marginRight: 10 }}/>
          </div>

          <Purpose purpose={props.contentItem.purpose} purposes={props.purposes} editMode={props.editMode} onEdit={props.onEditPurpose}/>

          <DeleteButton editMode={props.content.size > 1} onClick={props.onRemove}/>
        </div>
      </div>
      <div className="card-body p-2">{props.children}</div>
      <div className="reorder-mode-description">{getDescription(props)}</div>
    </div>);
};
const mapStateToProps = (state, ownProps) => {
    const { preferences } = state.preferences;
    return {
        preferences,
    };
};
const mapDispatchToProps = (dispatch, ownProps) => {
    return {
        onUpdatePreferences: ({ live_preview_display }) => dispatch(updatePreferences({ live_preview_display: valueOr(live_preview_display, null) })),
    };
};
const controller = connect(mapStateToProps, mapDispatchToProps)(ActivityBlock);
export { controller as ActivityBlock };
//# sourceMappingURL=ActivityBlock.jsx.map