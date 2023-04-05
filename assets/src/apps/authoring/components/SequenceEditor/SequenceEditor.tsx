import { saveActivity } from 'apps/authoring/store/activities/actions/saveActivity';
import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Accordion, ListGroup, OverlayTrigger, Tooltip, Dropdown } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import { useToggle } from '../../../../components/hooks/useToggle';
import { createNew as createNewActivity } from '../../../authoring/store/activities/actions/createNew';
import {
  selectAppMode,
  selectIsAdmin,
  selectProjectSlug,
  setCurrentRule,
  setRightPanelActiveTab,
} from '../../../authoring/store/app/slice';
import {
  selectAllActivities,
  selectCurrentActivity,
  upsertActivity,
} from '../../../delivery/store/features/activities/slice';
import {
  findInHierarchy,
  flattenHierarchy,
  getHierarchy,
  getSequenceLineage,
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
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
import { RightPanelTabs } from '../RightMenu/RightMenu';

const SequenceEditor: React.FC = () => {
  const dispatch = useDispatch();
  const currentSequenceId = useSelector(selectCurrentSequenceId);
  const sequence = useSelector(selectSequence);
  const currentGroup = useSelector(selectCurrentGroup);
  const currentActivity = useSelector(selectCurrentActivity);
  const allActivities = useSelector(selectAllActivities);
  const hierarchy = useMemo(() => getHierarchy(sequence), [sequence]);
  const [open, toggleOpen] = useToggle(true);

  const [itemToRename, setItemToRename] = useState<any>(undefined);
  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);
  const [itemToDelete, setItemToDelete] = useState<any>(undefined);

  const isAdmin = useSelector(selectIsAdmin);
  const projectSlug = useSelector(selectProjectSlug);

  const layerLabel = 'Layer';
  const bankLabel = 'Question Bank';
  const screenLabel = 'Screen';

  const handleItemClick = (e: any, entry: SequenceEntry<SequenceEntryChild>) => {
    e.stopPropagation();
    dispatch(setCurrentActivityFromSequence(entry.custom.sequenceId));
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
  };

  const addNewSequence = async (newSequenceEntry: any, siblingId: any) => {
    await dispatch(
      addSequenceItem({
        sequence: sequence,
        item: newSequenceEntry,
        group: currentGroup,
        siblingId: siblingId,
        // parentId: TODO attach parentId if it exists
      }),
    );

    dispatch(setCurrentActivityFromSequence(newSequenceEntry.custom.sequenceId));

    // will write the current groups
    await dispatch(savePage({ undoable: false }));
  };
  const handleItemAdd = async (
    parentItem: SequenceEntry<SequenceEntryChild> | undefined,
    isLayer = false,
    isBank = false,
  ) => {
    let layerRef: string | undefined;
    if (parentItem) {
      layerRef = parentItem.custom.sequenceId;
    }
    const newSeqType = isLayer ? layerLabel : isBank ? bankLabel : screenLabel;
    const newTitle = `New ${layerRef ? 'Child' : ''}${newSeqType}`;

    const { payload: newActivity } = await dispatch<any>(
      createNewActivity({
        title: newTitle,
      }),
    );

    const newSequenceEntry: any = {
      type: 'activity-reference',
      resourceId: newActivity.resourceId,
      activitySlug: newActivity.activitySlug,
      custom: {
        isLayer,
        isBank,
        layerRef,
        sequenceId: `${newActivity.activitySlug}_${guid()}`,
        sequenceName: newTitle,
      },
    };

    if (isBank) {
      newSequenceEntry.custom.bankEndTarget = 'next';
      newSequenceEntry.custom.bankShowCount = 3;
    }

    // maybe should set in the create?
    const reduxActivity = {
      id: newActivity.resourceId,
      resourceId: newActivity.resourceId,
      activitySlug: newActivity.activitySlug,
      activityType: newActivity.activityType,
      content: { ...newActivity.model, authoring: undefined },
      authoring: newActivity.model.authoring,
      title: newTitle,
      tags: [],
    };
    dispatch(saveActivity({ activity: reduxActivity, undoable: false, immediate: true }));
    await dispatch(upsertActivity({ activity: reduxActivity }));
    addNewSequence(newSequenceEntry, currentActivity?.activitySlug);
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
    await dispatch(savePage({ undoable: false }));
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
    itemsToDelete.forEach((item: SequenceEntry<SequenceEntryChild>) => {
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
    await dispatch(savePage({ undoable: false }));
    setShowConfirmDelete(false);
    setItemToDelete(undefined);
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
    await dispatch(savePage({ undoable: false }));
  };

  const handleItemClone = async (item: SequenceHierarchyItem<SequenceEntryType>) => {
    const newTitle = `Copy of ${item.custom.sequenceName}`;
    const { payload: newActivity } = await dispatch<any>(
      createNewActivity({
        title: newTitle,
      }),
    );

    const newSequenceEntry: any = {
      type: 'activity-reference',
      resourceId: newActivity.resourceId,
      activitySlug: newActivity.activitySlug,
      custom: {
        ...item.custom,
        sequenceId: `${newActivity.activitySlug}_${guid()}`,
        sequenceName: newTitle,
      },
    };

    const selectedActivity = allActivities.find((act) => act.id === item.resourceId);
    const copiedActivity = clone(selectedActivity);
    copiedActivity.id = newActivity.resourceId;
    copiedActivity.resourceId = newActivity.resourceId;
    copiedActivity.activitySlug = newActivity.activitySlug;
    copiedActivity.title = newTitle;
    dispatch(saveActivity({ activity: copiedActivity, undoable: false, immediate: true }));
    await dispatch(upsertActivity({ activity: copiedActivity }));
    addNewSequence(newSequenceEntry, item.activitySlug);
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
    await dispatch(savePage({ undoable: false }));
    setItemToRename(undefined);
  };

  const inputToFocus = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!itemToRename) return;
    inputToFocus.current?.focus();
  }, [itemToRename]);

  const SequenceItemContextMenu = (props: any) => {
    const { id, item, index, arr, isParentQB } = props;
    const isBank = item.custom.isBank;
    const isLayer = item.custom.isLayer;
    const seqType = isLayer ? layerLabel : isBank ? bankLabel : screenLabel;

    return (
      <>
        {currentGroup && (
          <Dropdown
            onClick={(e: React.MouseEvent) => {
              (e as any).isContextButtonClick = true;
            }}
          >
            <Dropdown.Toggle
              id={`sequence-item-${id}-context-trigger`}
              className="dropdown-toggle aa-context-menu-trigger btn btn-link p-0 px-1"
              variant="link"
            >
              <i className="fas fa-ellipsis-v" />
            </Dropdown.Toggle>

            <Dropdown.Menu>
              {!isParentQB && (
                <Dropdown.Item onClick={() => handleItemAdd(item)}>
                  <i className="fas fa-desktop mr-2" /> Add Subscreen
                </Dropdown.Item>
              )}

              {!isBank && !isParentQB && (
                <Dropdown.Item onClick={() => handleItemAdd(item, true)}>
                  <i className="fas fa-layer-group mr-2" /> Add Layer
                </Dropdown.Item>
              )}
              {!isBank && !isParentQB && (
                <Dropdown.Item onClick={() => handleItemAdd(item, false, true)}>
                  <i className="fas fa-cubes mr-2" /> Add Question Bank
                </Dropdown.Item>
              )}

              {isLayer ? (
                <Dropdown.Item onClick={() => handleItemConvert(item)}>
                  <i className="fas fa-exchange-alt mr-2" /> Convert to Screen
                </Dropdown.Item>
              ) : !isBank && !isParentQB ? (
                <Dropdown.Item onClick={() => handleItemConvert(item)}>
                  <i className="fas fa-exchange-alt mr-2" /> Convert to Layer
                </Dropdown.Item>
              ) : null}

              <Dropdown.Item onClick={() => setItemToRename(item)}>
                <i className="fas fa-i-cursor align-text-top mr-2" /> Rename
              </Dropdown.Item>

              {!isLayer && !isBank && (
                <Dropdown.Item onClick={() => handleItemClone(item)}>
                  <i className="fas fa-clone align-text-top mr-2" /> Clone Screen
                </Dropdown.Item>
              )}

              <Dropdown.Item onClick={() => navigator.clipboard.writeText(item.custom.sequenceId)}>
                <i className="fas fa-clipboard align-text-top mr-2" /> {`Copy ${seqType} ID`}
              </Dropdown.Item>

              {currentGroup?.children?.length > 1 && (
                <>
                  <div className="dropdown-divider" />
                  <Dropdown.Item
                    onClick={() => {
                      setShowConfirmDelete(true);
                      setItemToDelete(item);
                    }}
                  >
                    <i className="fas fa-trash mr-2" /> Delete
                  </Dropdown.Item>
                  <div className="dropdown-divider"></div>
                </>
              )}
              {index > 0 && (
                <Dropdown.Item onClick={(e) => handleItemReorder(e, item, ReorderDirection.UP)}>
                  <i className="fas fa-arrow-up mr-2" /> Move Up
                </Dropdown.Item>
              )}
              {index < arr.length - 1 && (
                <Dropdown.Item onClick={(e) => handleItemReorder(e, item, ReorderDirection.DOWN)}>
                  <i className="fas fa-arrow-down mr-2" /> Move Down
                </Dropdown.Item>
              )}
              {item.custom.layerRef && (
                <Dropdown.Item onClick={(e) => handleItemReorder(e, item, ReorderDirection.OUT)}>
                  <i className="fas fa-arrow-left mr-2" /> Move Out
                </Dropdown.Item>
              )}
              {index > 0 && arr.length > 1 && (
                <Dropdown.Item onClick={(e) => handleItemReorder(e, item, ReorderDirection.IN)}>
                  <i className="fas fa-arrow-right mr-2" /> Move In
                </Dropdown.Item>
              )}
              {isAdmin && (
                <>
                  <div className="dropdown-divider" />
                  <Dropdown.Item
                    onClick={() => {
                      // open revision history in new tab
                      window.open(`/project/${projectSlug}/history/resource_id/${item.resourceId}`);
                    }}
                  >
                    <i className="fas fa-history mr-2" /> Revision History (Admin)
                  </Dropdown.Item>
                  <div className="dropdown-divider"></div>
                </>
              )}

              {/* <div className="dropdown-divider"></div>
              <Dropdown.Item onClick={() => {}}>
                <i className="fas fa-copy mr-2" /> Copy
              </Dropdown.Item>
              <Dropdown.Item onClick={() => {}}>
                <i className="fas fa-paste mr-2" /> Paste as Child
              </Dropdown.Item>
              <Dropdown.Item onClick={() => {}}>
                <i className="fas fa-paste mr-2" /> Paste as Sibling
              </Dropdown.Item> */}
            </Dropdown.Menu>
          </Dropdown>
        )}
      </>
    );
  };

  useEffect(() => {
    // make sure that menus are expanded when the sequenceId is selected by any means
    if (!currentSequenceId) {
      return;
    }
    const lineage = getSequenceLineage(sequence, currentSequenceId);
    /* console.log('lineage', lineage); */
    // last one is the current sequence
    lineage.pop();
    lineage.reverse().forEach((item) => {
      const eventName = `toggle_${item.custom.sequenceId}`;
      document.dispatchEvent(new CustomEvent(eventName, { detail: 'expand' }));
    });
  }, [currentSequenceId, sequence]);

  const getHierarchyList = (items: any, isParentQB = false) =>
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
              onClick={(e) => !(e as any).isContextButtonClick && handleItemClick(e, item)}
              tabIndex={0}
            >
              <div className="aa-sequence-details-wrapper">
                <div className="details">
                  {item.children.length ? (
                    <ContextAwareToggle
                      eventKey={`toggle_${item.custom.sequenceId}`}
                      className={`aa-sequence-item-toggle`}
                    />
                  ) : null}
                  {!itemToRename ? (
                    <span className="title" title={item.custom.sequenceId}>
                      {title}
                    </span>
                  ) : itemToRename.custom.sequenceId !== item.custom.sequenceId ? (
                    <span className="title">{title}</span>
                  ) : null}
                  {itemToRename && itemToRename?.custom.sequenceId === item.custom.sequenceId && (
                    <input
                      ref={inputToFocus}
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
                  {item.custom.isBank && (
                    <i className="fas fa-cubes ml-2 align-middle aa-isLayer" />
                  )}
                </div>
                <SequenceItemContextMenu
                  id={item.activitySlug}
                  item={item}
                  index={index}
                  arr={arr}
                  isParentQB={isParentQB}
                />
              </div>
              {item.children.length ? (
                <Accordion.Collapse eventKey={`toggle_${item.custom.sequenceId}`}>
                  <ListGroup as="ol" className="aa-sequence nested">
                    {getHierarchyList(item.children, item.custom.isBank)}
                  </ListGroup>
                </Accordion.Collapse>
              ) : null}
            </ListGroup.Item>
          </Accordion>
        );
      },
    );

  return (
    <Accordion className="aa-sequence-editor" defaultActiveKey="0" activeKey={open ? '0' : '-1'}>
      <div className="aa-panel-section-title-bar">
        <div className="d-flex align-items-center">
          <ContextAwareToggle eventKey="0" onClick={toggleOpen} />
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
          <Dropdown>
            <Dropdown.Toggle variant="link" id="sequence-add">
              <i className="fa fa-plus" />
            </Dropdown.Toggle>

            <Dropdown.Menu>
              <Dropdown.Item
                onClick={(event) => {
                  handleItemAdd(undefined);
                }}
              >
                <i className="fas fa-desktop mr-2" /> Screen
              </Dropdown.Item>
              <Dropdown.Item
                onClick={() => {
                  handleItemAdd(undefined, true);
                }}
              >
                <i className="fas fa-layer-group mr-2" /> Layer
              </Dropdown.Item>
              <Dropdown.Item
                onClick={() => {
                  handleItemAdd(undefined, false, true);
                }}
              >
                <i className="fas fa-cubes mr-2" /> Question Bank
              </Dropdown.Item>
            </Dropdown.Menu>
          </Dropdown>
        </OverlayTrigger>
      </div>
      <Accordion.Collapse eventKey="0">
        <ListGroup as="ol" className="aa-sequence">
          {getHierarchyList(hierarchy)}
        </ListGroup>
      </Accordion.Collapse>
      {showConfirmDelete && (
        <ConfirmDelete
          show={showConfirmDelete}
          elementType={
            itemToDelete.custom?.isLayer
              ? 'Layer'
              : itemToDelete.custom?.isBank
              ? 'Question Bank'
              : 'Screen'
          }
          elementName={itemToDelete.custom?.sequenceName}
          deleteHandler={() => handleItemDelete(itemToDelete)}
          cancelHandler={() => {
            setShowConfirmDelete(false);
            setItemToDelete(undefined);
          }}
        />
      )}
    </Accordion>
  );
};

export default SequenceEditor;
