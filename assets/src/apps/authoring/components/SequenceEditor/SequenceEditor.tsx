import React from 'react';
import { Accordion, ListGroup, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import guid from 'utils/guid';
import { createNew as createNewActivity } from '../../../authoring/store/activities/actions/createNew';
import { upsertActivity } from '../../../delivery/store/features/activities/slice';
import {
  getHierarchy,
  SequenceEntry,
  SequenceEntryChild,
} from '../../../delivery/store/features/groups/actions/sequence';
import {
  selectCurrentSequenceId,
  selectSequence,
} from '../../../delivery/store/features/groups/selectors/deck';
import { selectCurrentGroup } from '../../../delivery/store/features/groups/slice';
import { addSequenceItem } from '../../store/groups/layouts/deck/actions/addSequenceItem';
import { setCurrentActivityFromSequence } from '../../store/groups/layouts/deck/actions/setCurrentActivityFromSequence';
import { savePage } from '../../store/page/actions/savePage';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';

const SequenceEditor: React.FC<any> = (props) => {
  const dispatch = useDispatch();
  const currentSequenceId = useSelector(selectCurrentSequenceId);
  const sequence = useSelector(selectSequence);
  const currentGroup = useSelector(selectCurrentGroup);

  const handleItemClick = (e: any, entry: SequenceEntry<SequenceEntryChild>) => {
    e.stopPropagation();
    dispatch(setCurrentActivityFromSequence(entry.custom.sequenceId));
  };

  const handleItemAdd = async (
    parentItem: SequenceEntry<SequenceEntryChild> | undefined,
    isLayer = false,
  ) => {
    let layerRef: string | undefined;
    if (parentItem) {
      layerRef = parentItem.custom.sequenceId;
    }
    const newTitle = `New ${layerRef ? 'Child' : ''}${isLayer ? 'Layer' : 'Screen'}`;

    const { payload: newActivity } = await dispatch<any>(
      createNewActivity({
        title: newTitle,
      }),
    );

    const newSequenceEntry = {
      type: 'activity-reference',
      resourceId: newActivity.resourceId,
      activitySlug: newActivity.activitySlug,
      custom: {
        isLayer,
        layerRef,
        sequenceId: `${newActivity.activitySlug}_${guid()}`,
        sequenceName: newTitle,
      },
    };

    // maybe should set in the create?
    const reduxActivity = {
      id: newActivity.resourceId,
      resourceId: newActivity.resourceId,
      activitySlug: newActivity.activitySlug,
      activityType: newActivity.activityType,
      content: { ...newActivity.model, authoring: undefined },
      authoring: newActivity.model.authoring,
    };

    await dispatch(upsertActivity({ activity: reduxActivity }));

    await dispatch(
      addSequenceItem({
        sequence: sequence,
        item: newSequenceEntry,
        group: currentGroup,
      }),
    );

    // will write the current groups
    await dispatch(savePage());
  };

  const SequenceItemContextMenu = (props: any) => {
    const { id } = props;

    return (
      <div className="dropdown aa-sequence-item-context-menu">
        <button
          className="dropdown-toggle aa-context-menu-trigger btn btn-link p-0 px-1"
          type="button"
          id={`sequence-item-${id}-context-trigger`}
          data-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
          onClick={(e) => {
            e.stopPropagation();
            ($(`#sequence-item-${id}-context-trigger`) as any).dropdown('toggle');
          }}
        >
          <i className="fas fa-ellipsis-v" />
        </button>
        <div
          id={`sequence-item-${id}-context-menu`}
          className="dropdown-menu"
          aria-labelledby={`sequence-item-${id}-context-trigger`}
        >
          <button
            className="dropdown-item"
            onClick={(e) => {
              e.stopPropagation();
              ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
            }}
          >
            <i className="fas fa-desktop mr-2" /> Add Subscreen
          </button>
          <button
            className="dropdown-item"
            onClick={(e) => {
              e.stopPropagation();
              ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
            }}
          >
            <i className="fas fa-layer-group mr-2" /> Add Layer
          </button>
          <button
            className="dropdown-item"
            onClick={(e) => {
              e.stopPropagation();
              ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
            }}
          >
            <i className="fas fa-exchange-alt mr-2" /> Convert to Layer
          </button>
          <button
            className="dropdown-item text-danger"
            onClick={(e) => {
              e.stopPropagation();
              ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
            }}
          >
            <i className="fas fa-trash mr-2" /> Delete
          </button>
          <div className="dropdown-divider"></div>
          <button
            className="dropdown-item"
            onClick={(e) => {
              e.stopPropagation();
              ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
            }}
          >
            <i className="fas fa-arrow-up mr-2" /> Move Up
          </button>
          <button
            className="dropdown-item"
            onClick={(e) => {
              e.stopPropagation();
              ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
            }}
          >
            <i className="fas fa-arrow-down mr-2" /> Move Down
          </button>
          <button
            className="dropdown-item"
            onClick={(e) => {
              e.stopPropagation();
              ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
            }}
          >
            <i className="fas fa-arrow-right mr-2" /> Move Right
          </button>
          <button
            className="dropdown-item"
            onClick={(e) => {
              e.stopPropagation();
              ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
            }}
          >
            <i className="fas fa-arrow-left mr-2" /> Move Left
          </button>
          <div className="dropdown-divider"></div>
          <button
            className="dropdown-item"
            onClick={(e) => {
              e.stopPropagation();
              ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
            }}
          >
            <i className="fas fa-copy mr-2" /> Copy
          </button>
          <button
            className="dropdown-item"
            onClick={(e) => {
              e.stopPropagation();
              ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
            }}
          >
            <i className="fas fa-paste mr-2" /> Paste as Child
          </button>
          <button
            className="dropdown-item"
            onClick={(e) => {
              e.stopPropagation();
              ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
            }}
          >
            <i className="fas fa-paste mr-2" /> Paste as Sibling
          </button>
        </div>
      </div>
    );
  };

  const hierarchy = getHierarchy(sequence);
  const getHierarchyList = (items: any) =>
    items.map((item: any, index: number) => {
      const title = item.custom?.sequenceName || item.id;
      return (
        <Accordion key={`${index}`}>
          <ListGroup.Item
            as="li"
            className={`aa-sequence-item${item.children.length ? ' is-parent' : ''}`}
            key={`${item.custom.sequenceId}`}
            active={item.custom.sequenceId === currentSequenceId}
            onClick={(e) => handleItemClick(e, item)}
            tabIndex={0}
          >
            <div className="aa-sequence-details-wrapper">
              <div className="details">
                {item.children.length ? (
                  <ContextAwareToggle eventKey={`${index}`} className={`aa-sequence-item-toggle`} />
                ) : null}
                <span className="title">{title}</span>
              </div>
              <SequenceItemContextMenu id={item.activitySlug} />
            </div>
            {item.children.length ? (
              <Accordion.Collapse eventKey={`${index}`}>
                <ListGroup as="ol" className="aa-sequence nested">
                  {getHierarchyList(item.children)}
                </ListGroup>
              </Accordion.Collapse>
            ) : null}
          </ListGroup.Item>
        </Accordion>
      );
    });

  return (
    <Accordion className="aa-sequence-editor" defaultActiveKey="0">
      <div className="aa-panel-section-title-bar">
        <div className="d-flex align-items-center">
          <ContextAwareToggle eventKey="0" />
          <span className="title">Sequence Editor</span>
        </div>
        <OverlayTrigger
          placement="right"
          delay={{ show: 150, hide: 150 }}
          overlay={
            <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
              New Sequence
            </Tooltip>
          }
        >
          <div className="dropdown">
            <button
              className="dropdown-toggle btn btn-link p-0"
              type="button"
              id="sequence-add"
              data-toggle="dropdown"
              aria-haspopup="true"
              aria-expanded="false"
            >
              <i className="fa fa-plus" />
            </button>
            <div
              id="sequence-add-contextMenu"
              className="dropdown-menu"
              aria-labelledby="sequence-add-contextMenu"
            >
              <button
                className="dropdown-item"
                onClick={() => {
                  handleItemAdd(undefined);
                }}
              >
                <i className="fas fa-desktop mr-2" /> Screen
              </button>
              <button
                className="dropdown-item"
                onClick={() => {
                  handleItemAdd(undefined, true);
                }}
              >
                <i className="fas fa-layer-group mr-2" /> Layer
              </button>
            </div>
          </div>
        </OverlayTrigger>
      </div>
      <Accordion.Collapse eventKey="0">
        <ListGroup as="ol" className="aa-sequence">
          {getHierarchyList(hierarchy)}
        </ListGroup>
      </Accordion.Collapse>
    </Accordion>
  );
};

export default SequenceEditor;
