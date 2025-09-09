import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Accordion, Dropdown, ListGroup, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { useDndContext } from '@dnd-kit/core';
import { SimpleTreeItemWrapper, SortableTree, TreeItemComponentProps } from 'dnd-kit-sortable-tree';
import { debounce } from 'lodash';
import { saveActivity } from 'apps/authoring/store/activities/actions/saveActivity';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import { useToggle } from '../../../../components/hooks/useToggle';
import { createNew as createNewActivity } from '../../../authoring/store/activities/actions/createNew';
import {
  selectBottomLeftPanel,
  setCurrentRule,
  setLeftPanelState,
  setRightPanelActiveTab,
} from '../../../authoring/store/app/slice';
import {
  selectAllActivities,
  selectCurrentActivity,
  upsertActivity,
} from '../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
  SequenceEntryType,
  SequenceHierarchyItem,
  findInHierarchy,
  flattenHierarchy,
  getHierarchy,
  getSequenceLineage,
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

const SequenceEditor: React.FC<any> = (props: any) => {
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
  const bottomLeftPanel = useSelector(selectBottomLeftPanel);
  const layerLabel = 'Layer';
  const bankLabel = 'Question Bank';
  const screenLabel = 'Screen';
  const ref = useRef<HTMLDivElement>(null);
  const refSequence = useRef<HTMLOListElement>(null);
  useEffect(() => {
    if (props.menuItemClicked) {
      const { event, item, parentItem, isLayer, isBank, direction } = props.menuItemClicked;
      switch (event) {
        case 'handleItemAdd':
          handleItemAdd(parentItem, isLayer, isBank);
          break;
        case 'handleItemReorder':
          handleItemReorder(null, item, direction);
          break;
        case 'handleItemDelete':
          setShowConfirmDelete(true);
          setItemToDelete(item);
          break;
        case 'handleItemConvert':
          handleItemConvert(item);
          break;
        case 'handleItemClone':
          handleItemClone(item);
          break;
        case 'setItemToRename':
          dispatch(setCurrentPartPropertyFocus({ focus: false }));
          setItemToRename(item);
          break;
        default:
          break;
      }
    }
  }, [props.menuItemClicked]);

  const handleItemClick = (e: any, entry: SequenceEntry<SequenceEntryChild>) => {
    e.stopPropagation();
    dispatch(setCurrentPartPropertyFocus({ focus: false }));
    dispatch(setCurrentActivityFromSequence(entry.custom.sequenceId));
    dispatch(
      setRightPanelActiveTab({
        _rightPanelActiveTab: RightPanelTabs.SCREEN,
        get rightPanelActiveTab() {
          return this._rightPanelActiveTab;
        },
        set rightPanelActiveTab(value) {
          this._rightPanelActiveTab = value;
        },
      }),
    );
    sequenceItemToggleClick();
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
            // if there is no parent , move within hierarchy
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
    itemInHierarchy.custom.sequenceName =
      item?.custom?.sequenceName || itemToRename?.custom?.sequenceName;
    activityClone.title = item?.custom?.sequenceName || itemToRename?.custom?.sequenceName;
    const newSequence = flattenHierarchy(hierarchyClone);
    const newGroup = { ...currentGroup, children: newSequence };
    dispatch(upsertGroup({ group: newGroup }));
    await dispatch(upsertActivity({ activity: activityClone }));
    await dispatch(savePage({ undoable: false }));
    setItemToRename(undefined);
  };

  const inputToFocus = useRef<HTMLInputElement>(null);

  const sequenceItemToggleClick = () => {
    setTimeout(() => {
      const scrollHeight = ref.current?.scrollHeight || 0;
      const sequenceClientHeight = refSequence?.current?.clientHeight || 0;
      dispatch(
        setLeftPanelState({
          sequenceEditorHeight: ref?.current?.clientHeight
            ? ref?.current?.clientHeight + 150
            : ref?.current?.clientHeight,
          sequenceEditorExpanded: scrollHeight < sequenceClientHeight ? true : false,
        }),
      );
    }, 1000);
  };
  useEffect(() => {
    if (!itemToRename) return;
    inputToFocus.current?.focus();
  }, [itemToRename]);

  const SequenceItemContextMenu = (props: any) => {
    const { id } = props;
    return (
      <>
        {currentGroup && (
          <Dropdown
            onClick={(e: React.MouseEvent) => {
              (e as any).isContextButtonClick = true;
              props.contextMenuClicked(true, props);
            }}
          >
            <Dropdown.Toggle
              id={`sequence-item-${id}-context-trigger`}
              className="dropdown-toggle aa-context-menu-trigger btn btn-link p-0 px-1"
              variant="link"
            >
              <i className="fas fa-ellipsis-v" />
            </Dropdown.Toggle>
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

  // eslint-disable-next-line react/display-name
  const TreeItem = React.forwardRef<HTMLDivElement, TreeItemComponentProps<any>>((props, ref) => {
    const { item, depth } = props;
    const { active } = useDndContext();
    const title = item?.custom?.sequenceName || props?.item?.activitySlug;
    const itemToRenameInTree = item.parameters.itemToRename;
    const inputToFocus = useRef<HTMLInputElement>(null);
    const liRef = useRef<HTMLLIElement>(null);
    const [sequenceTitle, setSequenceTitle] = useState<any>(title);
    const indent = depth * 10;

    useEffect(() => {
      if (
        itemToRenameInTree &&
        itemToRenameInTree.custom.sequenceId === item.custom.sequenceId &&
        inputToFocus.current
      ) {
        inputToFocus.current.focus();
      }
    }, [itemToRenameInTree, item.custom.sequenceId]);
    useEffect(() => {
      if (
        !item.parameters.hierarchyDnDEnabled &&
        item.custom.sequenceId === item.parameters.currentSequenceId &&
        liRef?.current &&
        !itemToRenameInTree &&
        !active
      ) {
        requestAnimationFrame(() => {
          liRef.current?.focus();
          liRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
        });
      }
    }, [item, itemToRenameInTree, item.parameters.currentSequenceId, active]);

    return (
      <SimpleTreeItemWrapper {...props} ref={ref}>
        <ListGroup.Item
          ref={liRef}
          as="li"
          className={`aa-sequence-item${props?.item?.children?.length ? ' is-parent' : ''}`}
          style={{ width: '100%', paddingLeft: `${indent}px` }}
          key={`${props.item.id}`}
          active={item.custom.sequenceId === item.parameters.currentSequenceId}
          tabIndex={0}
          onClick={(e) => {
            if (!item.parameters.hierarchyDnDEnabled) {
              !(e as any).isContextButtonClick && item.parameters.handleItemClick(e, item);
              item.parameters.contextMenuClicked((e as any).isContextButtonClick);
            }
          }}
        >
          <div
            className="aa-sequence-details-wrapper"
            style={{ width: '100%', paddingLeft: '5px' }}
          >
            <div className="details" style={{ width: '100%' }}>
              {!itemToRenameInTree ? (
                <span className="title" style={{ width: '100%' }} title={item.custom.sequenceId}>
                  {sequenceTitle}
                </span>
              ) : itemToRenameInTree.custom.sequenceId !== item.custom.sequenceId ? (
                <span className="title">{sequenceTitle}</span>
              ) : null}
              {!item.parameters.hierarchyDnDEnabled &&
                itemToRenameInTree &&
                itemToRenameInTree?.custom.sequenceId === item.custom.sequenceId && (
                  <input
                    ref={inputToFocus}
                    className="form-control form-control-sm rename-sequence-input"
                    type="text"
                    placeholder={item.custom.isLayer ? 'Layer name' : 'Screen name'}
                    value={sequenceTitle}
                    onClick={(e) => e.preventDefault()}
                    onChange={(e) => setSequenceTitle(e.target.value)}
                    onFocus={(e) => {
                      e.target.select();
                      // eslint-disable-next-line @typescript-eslint/no-unsafe-call
                      item.parameters.setCurrentPartPropertyFocus({ focus: false });
                    }}
                    onBlur={() => {
                      item.parameters.setItemToRename({
                        ...itemToRenameInTree,
                        custom: { ...itemToRenameInTree.custom, sequenceName: sequenceTitle },
                      });
                      item.parameters.handleRenameItem({
                        ...item,
                        custom: { ...itemToRenameInTree.custom, sequenceName: sequenceTitle },
                      });
                      // eslint-disable-next-line @typescript-eslint/no-unsafe-call
                      item.parameters.setCurrentPartPropertyFocus({ focus: true });
                    }}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') {
                        const updatedItem = {
                          ...item,
                          custom: { ...item.custom, sequenceName: sequenceTitle },
                        };
                        item.parameters.setItemToRename(updatedItem);
                        item.parameters.handleRenameItem(updatedItem);
                      }
                      if (e.key === 'Escape') item.parameters.setItemToRename(undefined);
                    }}
                  />
                )}

              {!active && item.custom.isLayer && (
                <i className="fas fa-layer-group ml-2 align-middle aa-isLayer" />
              )}
              {!active && item.custom.isBank && (
                <i className="fas fa-cubes ml-2 align-middle aa-isLayer" />
              )}
            </div>
            {!active && !item.parameters.hierarchyDnDEnabled && (
              <SequenceItemContextMenu
                id={item.activitySlug}
                item={item}
                index={item.parameters.index}
                arr={item.parameters.arr}
                isParentQB={item.parameters.isParentQB}
                contextMenuClicked={item.parameters.contextMenuClicked}
              />
            )}
          </div>
        </ListGroup.Item>
      </SimpleTreeItemWrapper>
    );
  });
  const manageTreeData = useCallback(
    (data: any) => {
      return data.map((item: any, index: number) => {
        const newItem: any = {
          id: item?.id || guid(),
          ...item,
          parameters: {
            contextMenuClicked: props?.contextMenuClicked,
            itemToRename,
            index, // This index is specific to the current level
            arr: data?.length,
            isParentQB: item.custom.isBank,
            currentSequenceId,
            setCurrentPartPropertyFocus,
            handleRenameItem,
            setItemToRename,
            handleItemClick,
          },
        };

        // 🚀 If the item has children, recursively call manageTreeData on them
        if (item.children && item.children.length > 0) {
          newItem.children = manageTreeData(item.children); // Recursion!
        }
        return newItem;
      });
    },
    [
      itemToRename,
      currentSequenceId,
      props?.setItemToRename,
      handleRenameItem,
      handleItemClick,
      props.contextMenuClicked,
    ],
  );

  // Debounce savePage so it fires only after 500ms of no drag updates
  const debouncedSave = useCallback(
    debounce(async (newAfterFlattenGroup: any) => {
      await dispatch(upsertGroup({ group: newAfterFlattenGroup }));
      await dispatch(savePage({ undoable: false }));
    }, 500),
    [],
  );
  const lastSavedOrder = useRef<string[]>([]);
  const getSequenceOrder = (items: any[], parentId: string | null = null): string[] => {
    let order: string[] = [];
    items.forEach((item) => {
      order.push(`${parentId ?? 'root'}:${item.custom.sequenceId}`);
      if (item.children?.length) {
        order = order.concat(getSequenceOrder(item.children, item.custom.sequenceId));
      }
    });
    return order;
  };
  const [treeItems, setTreeItems] = useState<any[]>(manageTreeData(hierarchy));
  useEffect(() => {
    setTreeItems(manageTreeData(hierarchy));
  }, [hierarchy, itemToRename, currentSequenceId]);

  return (
    <Accordion
      className="aa-sequence-editor"
      ref={ref}
      defaultActiveKey="0"
      activeKey={open ? '0' : '-1'}
      style={{
        height: !bottomLeftPanel && open ? 'calc(100vh - 100px)' : 'auto',
        maxHeight: !bottomLeftPanel && open ? 'calc(100vh - 100px)' : '60vh',
        overflow: 'hidden',
      }}
    >
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
                onClick={() => {
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
      <Accordion.Collapse
        eventKey="0"
        style={{
          overflowY: 'auto',
          maxHeight: !bottomLeftPanel && open ? 'calc(100vh - 100px)' : '55vh',
        }}
      >
        <div className="border border-gray-300 rounded">
          <ListGroup ref={refSequence} as="ol" className="aa-sequence">
            <SortableTree
              items={treeItems}
              onItemsChanged={async (items) => {
                setTreeItems(items);
                // Build the current order signature (order + parent hierarchy)
                const currentOrder = getSequenceOrder(items);
                const prevOrder = lastSavedOrder.current;
                // Compare orders → same length and same item sequence means no change
                const isSameOrder =
                  currentOrder.length === prevOrder.length &&
                  currentOrder.every((id, idx) => id === prevOrder[idx]);
                // If order/hierarchy unchanged → skip saving to avoid unnecessary API calls
                if (isSameOrder) {
                  console.log('No sequence change → skipping save');
                  return;
                }
                lastSavedOrder.current = currentOrder; // store only if changed

                // Recursively set each node's layerRef to its parent's sequenceId
                // Ensures correct parent-child relationships after drag-and-drop
                const assignLayerRef = (nodes: any, parentSequenceId = '') => {
                  return nodes.map((node: any) => {
                    const newNode = { ...node, custom: { ...node.custom } };

                    if (parentSequenceId) {
                      newNode.custom.layerRef = parentSequenceId;
                    }

                    const nodeSequenceId = node?.custom?.sequenceId || '';
                    if (newNode.children?.length) {
                      newNode.children = assignLayerRef(newNode.children, nodeSequenceId);
                    }
                    return newNode;
                  });
                };

                const updatedItems = assignLayerRef(items);
                const newSequence = clone(flattenHierarchy(updatedItems));
                const newGroup = { ...currentGroup, children: newSequence };
                // Debounced save so we don't call on every drag step
                debouncedSave(newGroup);
              }}
              TreeItemComponent={TreeItem}
            />
          </ListGroup>
        </div>
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
