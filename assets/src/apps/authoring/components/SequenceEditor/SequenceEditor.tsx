import React, { useEffect, useState } from 'react';
import { Accordion, ListGroup, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import { createNew as createNewActivity } from '../../../authoring/store/activities/actions/createNew';
import { setCurrentRule, setRightPanelActiveTab } from '../../../authoring/store/app/slice';
import {
  selectCurrentActivity,
  upsertActivity,
} from '../../../delivery/store/features/activities/slice';
import {
  findInHierarchy,
  flattenHierarchy,
  getHierarchy,
  SequenceEntry,
  SequenceEntryChild,
  SequenceEntryType,
  SequenceHierarchyItem,
} from '../../../delivery/store/features/groups/actions/sequence';
import {
  selectCurrentSequenceId,
  selectSequence,
} from '../../../delivery/store/features/groups/selectors/deck';
import { selectCurrentGroup, upsertGroup } from '../../../delivery/store/features/groups/slice';
import { addSequenceItem } from '../../store/groups/layouts/deck/actions/addSequenceItem';
import { setCurrentActivityFromSequence } from '../../store/groups/layouts/deck/actions/setCurrentActivityFromSequence';
import { savePage } from '../../store/page/actions/savePage';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';
import { RightPanelTabs } from '../RightMenu/RightMenu';

const SequenceEditor: React.FC<any> = (props) => {
  const dispatch = useDispatch();
  const currentSequenceId = useSelector(selectCurrentSequenceId);
  const sequence = useSelector(selectSequence);
  const currentGroup = useSelector(selectCurrentGroup);
  const currentActivity = useSelector(selectCurrentActivity);
  const [hierarchy, setHierarchy] = useState(getHierarchy(sequence));
  const [itemToRename, setItemToRename] = useState<any>(undefined);

  useEffect(() => {
    const newHierarchy: SequenceHierarchyItem<SequenceEntryChild>[] = getHierarchy(sequence);
    return setHierarchy(newHierarchy);
  }, [sequence]);

  const handleItemClick = (e: any, entry: SequenceEntry<SequenceEntryChild>) => {
    e.stopPropagation();
    dispatch(setCurrentActivityFromSequence(entry.custom.sequenceId));
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
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
        siblingId: currentActivity?.activitySlug,
        // parentId: TODO attach parentId if it exists
      }),
    );

    dispatch(setCurrentActivityFromSequence(newSequenceEntry.custom.sequenceId));

    // will write the current groups
    await dispatch(savePage());
  };

  enum ReorderDirection {
    UP = 0,
    DOWN,
    IN,
    OUT,
  }
  const handleItemReorder = async (
    event: any,
    item: SequenceHierarchyItem<SequenceEntryType>,
    direction: ReorderDirection,
  ) => {
    let hierarchyCopy = clone(hierarchy);
    const parentId = item.custom.layerRef;
    let itemIndex = -1;
    let parent: any = null;
    if (parentId) {
      parent = findInHierarchy(hierarchyCopy, parentId);
      if (!parent) {
        console.error('parent not found?');
        return;
      }
      itemIndex = parent.children.findIndex(
        (child: SequenceHierarchyItem<SequenceEntryType>) =>
          child.custom.sequenceId === item.custom.sequenceId,
      );
    } else {
      itemIndex = hierarchyCopy.findIndex(
        (child: SequenceHierarchyItem<SequenceEntryType>) =>
          child.custom.sequenceId === item.custom.sequenceId,
      );
    }
    const move = (from: number, to: number, arr: SequenceHierarchyItem<SequenceEntryType>[]) => {
      arr.splice(to, 0, ...arr.splice(from, 1));
    };

    switch (direction) {
      case ReorderDirection.UP:
        {
          if (parent) {
            move(itemIndex, itemIndex - 1, parent.children);
          } else {
            // if there is no parent, move within hierarchy
            move(itemIndex, itemIndex - 1, hierarchyCopy);
          }
        }
        break;
      case ReorderDirection.DOWN:
        {
          if (parent) {
            move(itemIndex, itemIndex + 1, parent.children);
          } else {
            // if there is no parent, move within hierarchy
            move(itemIndex, itemIndex + 1, hierarchyCopy);
          }
        }
        break;
      case ReorderDirection.IN:
        {
          let sibling;
          if (parent) {
            sibling = parent.children[itemIndex - 1];
            parent.children = parent.children.filter(
              (i: SequenceHierarchyItem<SequenceEntryType>) =>
                i.custom.sequenceId !== item.custom.sequenceId,
            );
          } else {
            sibling = hierarchyCopy[itemIndex - 1];
            hierarchyCopy = hierarchyCopy.filter(
              (i: SequenceHierarchyItem<SequenceEntryType>) =>
                i.custom.sequenceId !== item.custom.sequenceId,
            );
          }
          if (!sibling) {
            console.error('no sibling above to move "in" to');
            return;
          }
          const itemCopy = clone(item);
          itemCopy.custom.layerRef = sibling.custom.sequenceId;
          sibling.children.push(itemCopy);
        }
        break;
      case ReorderDirection.OUT:
        {
          if (!parent) {
            console.error('no parent to move out of');
            return;
          }
          // we want to pull out and become a sibling to the parent
          parent.children = parent.children.filter(
            (i: SequenceHierarchyItem<SequenceEntryType>) =>
              i.custom.sequenceId !== item.custom.sequenceId,
          );
          if (parent.custom.layerRef) {
            const grandparent: any = findInHierarchy(hierarchyCopy, parent.custom.layerRef);
            if (!grandparent) {
              console.error('no grandparent found? ' + parent.custom.layerRef);
              return;
            }
            const parentIndex = grandparent.children.findIndex(
              (i: SequenceHierarchyItem<SequenceEntryType>) =>
                i.custom.sequenceId === parent.custom.sequenceId,
            );
            const itemCopy = clone(item);
            itemCopy.custom.layerRef = grandparent.custom.sequenceId;
            grandparent.children.splice(parentIndex + 1, 0, itemCopy);
          } else {
            // the parent lives in the root
            const parentIndex = hierarchyCopy.findIndex(
              (i: SequenceHierarchyItem<SequenceEntryType>) =>
                i.custom.sequenceId === parent.custom.sequenceId,
            );
            const itemCopy = clone(item);
            itemCopy.custom.layerRef = '';
            hierarchyCopy.splice(parentIndex + 1, 0, itemCopy);
          }
        }
        break;
      default:
        throw new Error('Uknown reorder direction! ' + direction);
    }
    const newSequence = clone(flattenHierarchy(hierarchyCopy));
    const newGroup = { ...currentGroup, children: newSequence };
    dispatch(upsertGroup({ group: newGroup }));
    await dispatch(savePage());
  };

  const handleItemDelete = async (item: SequenceHierarchyItem<SequenceEntryType>) => {
    const flatten = (parent: SequenceHierarchyItem<SequenceEntryType>) => {
      const list = [{ ...parent, children: undefined }];
      parent.children.forEach((child) => {
        list.push(...flatten(child));
      });
      return list;
    };
    const itemsToDelete = flatten(item);
    const sequenceItems = [...sequence];
    itemsToDelete.forEach((item: any) => {
      if (item.activitySlug === currentActivity?.activitySlug)
        dispatch(setCurrentRule({ currentRule: undefined }));
      const itemIndex = sequenceItems.findIndex(
        (entry) => entry.custom.sequenceId === item.custom.sequenceId,
      );
      if (itemIndex < 0) {
        console.warn('not found in sequence', item);
        return;
      }
      sequenceItems.splice(itemIndex, 1);
    });
    const newGroup = { ...currentGroup, children: sequenceItems };
    dispatch(upsertGroup({ group: newGroup }));
    await dispatch(savePage());
  };

  const handleItemConvert = async (item: SequenceHierarchyItem<SequenceEntryType>) => {
    const hierarchyCopy = clone(hierarchy);
    const itemInHierarchy = findInHierarchy(hierarchyCopy, item.custom.sequenceId);
    if (itemInHierarchy === undefined) {
      return console.warn('item not converted', item);
    }
    const isLayer = !!itemInHierarchy?.custom.isLayer || false;
    itemInHierarchy.custom.isLayer = !isLayer;
    const newSequence = flattenHierarchy(hierarchyCopy);
    const newGroup = { ...currentGroup, children: newSequence };
    dispatch(upsertGroup({ group: newGroup }));
    await dispatch(savePage());
  };

  const handleRenameItem = async (item: any) => {
    if (itemToRename.custom.sequenceName.trim() === '') {
      setItemToRename(undefined);
      return;
    }
    if (itemToRename.custom.sequenceName === item.custom.sequenceName) {
      setItemToRename(undefined);
      return;
    }
    const hierarchyClone = clone(hierarchy);
    const activityClone = clone(currentActivity);
    const itemInHierarchy = findInHierarchy(hierarchyClone, item.custom.sequenceId);
    if (itemInHierarchy === undefined || activityClone === undefined) {
      return console.warn('item not renamed', item);
    }
    itemInHierarchy.custom.sequenceName = itemToRename.custom.sequenceName;
    activityClone.title = itemToRename.custom.sequenceName;
    const newSequence = flattenHierarchy(hierarchyClone);
    const newGroup = { ...currentGroup, children: newSequence };
    dispatch(upsertGroup({ group: newGroup }));
    await dispatch(upsertActivity({ activity: activityClone }));
    await dispatch(savePage());
    setItemToRename(undefined);
  };

  useEffect(() => {
    if (!itemToRename) return;
    const inputToFocus = document.getElementById('input-sequence-item-name');
    if (inputToFocus) inputToFocus.focus();
  }, [itemToRename]);

  const SequenceItemContextMenu = (props: any) => {
    const { id, item, index, arr } = props;

    return (
      <div className="dropdown aa-sequence-item-context-menu">
        {currentGroup && (
          <>
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
                  handleItemAdd(item);
                }}
              >
                <i className="fas fa-desktop mr-2" /> Add Subscreen
              </button>
              <button
                className="dropdown-item"
                onClick={(e) => {
                  e.stopPropagation();
                  ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
                  handleItemAdd(item, true);
                }}
              >
                <i className="fas fa-layer-group mr-2" /> Add Layer
              </button>
              {item.custom.isLayer ? (
                <button
                  className="dropdown-item"
                  onClick={(e) => {
                    e.stopPropagation();
                    ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
                    handleItemConvert(item);
                  }}
                >
                  <i className="fas fa-exchange-alt mr-2" /> Convert to Screen
                </button>
              ) : (
                <button
                  className="dropdown-item"
                  onClick={(e) => {
                    e.stopPropagation();
                    ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
                    handleItemConvert(item);
                  }}
                >
                  <i className="fas fa-exchange-alt mr-2" /> Convert to Layer
                </button>
              )}
              <button
                className="dropdown-item"
                onClick={(e) => {
                  e.stopPropagation();
                  ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
                  setItemToRename(item);
                }}
              >
                <i className="fas fa-i-cursor align-text-top mr-2" /> Rename
              </button>
              <button
                className="dropdown-item"
                onClick={(e) => {
                  e.stopPropagation();
                  ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
                  navigator.clipboard.writeText(item.custom.sequenceId);
                }}
              >
                <i className="fas fa-clipboard align-text-top mr-2" /> Copy{' '}
                {item.custom.isLayer ? 'Layer' : 'Screen'} ID
              </button>
              {currentGroup?.children?.length > 1 && (
                <>
                  <div className="dropdown-divider" />
                  <button
                    className="dropdown-item text-danger"
                    onClick={(e) => {
                      e.stopPropagation();
                      ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
                      handleItemDelete(item);
                    }}
                  >
                    <i className="fas fa-trash mr-2" /> Delete
                  </button>
                  <div className="dropdown-divider"></div>
                </>
              )}
              {index > 0 && (
                <button
                  className="dropdown-item"
                  onClick={(e) => {
                    e.stopPropagation();
                    ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
                    handleItemReorder(e, item, ReorderDirection.UP);
                  }}
                >
                  <i className="fas fa-arrow-up mr-2" /> Move Up
                </button>
              )}
              {index < arr.length - 1 && (
                <button
                  className="dropdown-item"
                  onClick={(e) => {
                    e.stopPropagation();
                    ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
                    handleItemReorder(e, item, ReorderDirection.DOWN);
                  }}
                >
                  <i className="fas fa-arrow-down mr-2" /> Move Down
                </button>
              )}
              {item.custom.layerRef && (
                <button
                  className="dropdown-item"
                  onClick={(e) => {
                    e.stopPropagation();
                    ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
                    handleItemReorder(e, item, ReorderDirection.OUT);
                  }}
                >
                  <i className="fas fa-arrow-left mr-2" /> Move Out
                </button>
              )}
              {index > 0 && arr.length > 1 && (
                <button
                  className="dropdown-item"
                  onClick={(e) => {
                    e.stopPropagation();
                    ($(`#sequence-item-${id}-context-menu`) as any).dropdown('toggle');
                    handleItemReorder(e, item, ReorderDirection.IN);
                  }}
                >
                  <i className="fas fa-arrow-right mr-2" /> Move In
                </button>
              )}
              {/* <div className="dropdown-divider"></div>
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
          </button> */}
            </div>
          </>
        )}
      </div>
    );
  };

  const getHierarchyList = (items: any) =>
    items.map(
      (
        item: SequenceHierarchyItem<SequenceEntryType>,
        index: number,
        arr: SequenceHierarchyItem<SequenceEntryType>,
      ) => {
        const title = item.custom?.sequenceName || item.activitySlug;
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
                    <ContextAwareToggle
                      eventKey={`${index}`}
                      className={`aa-sequence-item-toggle`}
                    />
                  ) : null}
                  {!itemToRename ? (
                    <span className="title">{title}</span>
                  ) : itemToRename.custom.sequenceId !== item.custom.sequenceId ? (
                    <span className="title">{title}</span>
                  ) : null}
                  {itemToRename && itemToRename?.custom.sequenceId === item.custom.sequenceId && (
                    <input
                      id="input-sequence-item-name"
                      className="form-control form-control-sm"
                      type="text"
                      placeholder={item.custom.isLayer ? 'Layer name' : 'Screen name'}
                      value={itemToRename.custom.sequenceName}
                      onClick={(e) => e.preventDefault()}
                      onChange={(e) =>
                        setItemToRename({
                          ...itemToRename,
                          custom: { ...itemToRename.custom, sequenceName: e.target.value },
                        })
                      }
                      onFocus={(e) => e.target.select()}
                      onBlur={() => handleRenameItem(item)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') handleRenameItem(item);
                        if (e.key === 'Escape') setItemToRename(undefined);
                      }}
                    />
                  )}
                  {item.custom.isLayer && (
                    <i className="fas fa-layer-group ml-2 align-middle aa-isLayer" />
                  )}
                </div>
                <SequenceItemContextMenu
                  id={item.activitySlug}
                  item={item}
                  index={index}
                  arr={arr}
                />
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
      },
    );

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
