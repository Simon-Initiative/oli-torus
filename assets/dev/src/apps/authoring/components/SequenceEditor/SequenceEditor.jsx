var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { saveActivity } from 'apps/authoring/store/activities/actions/saveActivity';
import React, { useEffect, useState } from 'react';
import { Accordion, ListGroup, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import { createNew as createNewActivity } from '../../../authoring/store/activities/actions/createNew';
import { setCurrentRule, setRightPanelActiveTab } from '../../../authoring/store/app/slice';
import { selectAllActivities, selectCurrentActivity, upsertActivity, } from '../../../delivery/store/features/activities/slice';
import { findInHierarchy, flattenHierarchy, getHierarchy, getSequenceLineage, } from '../../../delivery/store/features/groups/actions/sequence';
import { selectCurrentSequenceId, selectSequence, } from '../../../delivery/store/features/groups/selectors/deck';
import { selectCurrentGroup, upsertGroup } from '../../../delivery/store/features/groups/slice';
import { addSequenceItem } from '../../store/groups/layouts/deck/actions/addSequenceItem';
import { setCurrentActivityFromSequence } from '../../store/groups/layouts/deck/actions/setCurrentActivityFromSequence';
import { savePage } from '../../store/page/actions/savePage';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
import { RightPanelTabs } from '../RightMenu/RightMenu';
const SequenceEditor = () => {
    var _a, _b, _c;
    const dispatch = useDispatch();
    const currentSequenceId = useSelector(selectCurrentSequenceId);
    const sequence = useSelector(selectSequence);
    const currentGroup = useSelector(selectCurrentGroup);
    const currentActivity = useSelector(selectCurrentActivity);
    const allActivities = useSelector(selectAllActivities);
    const [hierarchy, setHierarchy] = useState(getHierarchy(sequence));
    const [itemToRename, setItemToRename] = useState(undefined);
    const [showConfirmDelete, setShowConfirmDelete] = useState(false);
    const [itemToDelete, setItemToDelete] = useState(undefined);
    const layerLabel = 'Layer';
    const bankLabel = 'Question Bank';
    const screenLabel = 'Screen';
    useEffect(() => {
        const newHierarchy = getHierarchy(sequence);
        return setHierarchy(newHierarchy);
    }, [sequence]);
    const handleItemClick = (e, entry) => {
        e.stopPropagation();
        dispatch(setCurrentActivityFromSequence(entry.custom.sequenceId));
        dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
    };
    const addNewSequence = (newSequenceEntry, siblingId) => __awaiter(void 0, void 0, void 0, function* () {
        yield dispatch(addSequenceItem({
            sequence: sequence,
            item: newSequenceEntry,
            group: currentGroup,
            siblingId: siblingId,
            // parentId: TODO attach parentId if it exists
        }));
        dispatch(setCurrentActivityFromSequence(newSequenceEntry.custom.sequenceId));
        // will write the current groups
        yield dispatch(savePage());
    });
    const handleItemAdd = (parentItem, isLayer = false, isBank = false) => __awaiter(void 0, void 0, void 0, function* () {
        let layerRef;
        if (parentItem) {
            layerRef = parentItem.custom.sequenceId;
        }
        const newSeqType = isLayer ? layerLabel : isBank ? bankLabel : screenLabel;
        const newTitle = `New ${layerRef ? 'Child' : ''}${newSeqType}`;
        const { payload: newActivity } = yield dispatch(createNewActivity({
            title: newTitle,
        }));
        const newSequenceEntry = {
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
            content: Object.assign(Object.assign({}, newActivity.model), { authoring: undefined }),
            authoring: newActivity.model.authoring,
        };
        yield dispatch(upsertActivity({ activity: reduxActivity }));
        addNewSequence(newSequenceEntry, currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.activitySlug);
    });
    let ReorderDirection;
    (function (ReorderDirection) {
        ReorderDirection[ReorderDirection["UP"] = 0] = "UP";
        ReorderDirection[ReorderDirection["DOWN"] = 1] = "DOWN";
        ReorderDirection[ReorderDirection["IN"] = 2] = "IN";
        ReorderDirection[ReorderDirection["OUT"] = 3] = "OUT";
    })(ReorderDirection || (ReorderDirection = {}));
    const handleItemReorder = (event, item, direction) => __awaiter(void 0, void 0, void 0, function* () {
        let hierarchyCopy = clone(hierarchy);
        const parentId = item.custom.layerRef;
        let itemIndex = -1;
        let parent = null;
        if (parentId) {
            parent = findInHierarchy(hierarchyCopy, parentId);
            if (!parent) {
                console.error('parent not found?');
                return;
            }
            itemIndex = parent.children.findIndex((child) => child.custom.sequenceId === item.custom.sequenceId);
        }
        else {
            itemIndex = hierarchyCopy.findIndex((child) => child.custom.sequenceId === item.custom.sequenceId);
        }
        const move = (from, to, arr) => {
            arr.splice(to, 0, ...arr.splice(from, 1));
        };
        switch (direction) {
            case ReorderDirection.UP:
                {
                    if (parent) {
                        move(itemIndex, itemIndex - 1, parent.children);
                    }
                    else {
                        // if there is no parent, move within hierarchy
                        move(itemIndex, itemIndex - 1, hierarchyCopy);
                    }
                }
                break;
            case ReorderDirection.DOWN:
                {
                    if (parent) {
                        move(itemIndex, itemIndex + 1, parent.children);
                    }
                    else {
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
                        parent.children = parent.children.filter((i) => i.custom.sequenceId !== item.custom.sequenceId);
                    }
                    else {
                        sibling = hierarchyCopy[itemIndex - 1];
                        hierarchyCopy = hierarchyCopy.filter((i) => i.custom.sequenceId !== item.custom.sequenceId);
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
                    parent.children = parent.children.filter((i) => i.custom.sequenceId !== item.custom.sequenceId);
                    if (parent.custom.layerRef) {
                        const grandparent = findInHierarchy(hierarchyCopy, parent.custom.layerRef);
                        if (!grandparent) {
                            console.error('no grandparent found? ' + parent.custom.layerRef);
                            return;
                        }
                        const parentIndex = grandparent.children.findIndex((i) => i.custom.sequenceId === parent.custom.sequenceId);
                        const itemCopy = clone(item);
                        itemCopy.custom.layerRef = grandparent.custom.sequenceId;
                        grandparent.children.splice(parentIndex + 1, 0, itemCopy);
                    }
                    else {
                        // the parent lives in the root
                        const parentIndex = hierarchyCopy.findIndex((i) => i.custom.sequenceId === parent.custom.sequenceId);
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
        const newGroup = Object.assign(Object.assign({}, currentGroup), { children: newSequence });
        dispatch(upsertGroup({ group: newGroup }));
        yield dispatch(savePage());
    });
    const handleItemDelete = (item) => __awaiter(void 0, void 0, void 0, function* () {
        const flatten = (parent) => {
            const list = [Object.assign(Object.assign({}, parent), { children: undefined })];
            parent.children.forEach((child) => {
                list.push(...flatten(child));
            });
            return list;
        };
        const itemsToDelete = flatten(item);
        const sequenceItems = [...sequence];
        itemsToDelete.forEach((item) => {
            if (item.activitySlug === (currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.activitySlug))
                dispatch(setCurrentRule({ currentRule: undefined }));
            const itemIndex = sequenceItems.findIndex((entry) => entry.custom.sequenceId === item.custom.sequenceId);
            if (itemIndex < 0) {
                console.warn('not found in sequence', item);
                return;
            }
            sequenceItems.splice(itemIndex, 1);
        });
        const newGroup = Object.assign(Object.assign({}, currentGroup), { children: sequenceItems });
        dispatch(upsertGroup({ group: newGroup }));
        yield dispatch(savePage());
        setShowConfirmDelete(false);
        setItemToDelete(undefined);
    });
    const handleItemConvert = (item) => __awaiter(void 0, void 0, void 0, function* () {
        const hierarchyCopy = clone(hierarchy);
        const itemInHierarchy = findInHierarchy(hierarchyCopy, item.custom.sequenceId);
        if (itemInHierarchy === undefined) {
            return console.warn('item not converted', item);
        }
        const isLayer = !!(itemInHierarchy === null || itemInHierarchy === void 0 ? void 0 : itemInHierarchy.custom.isLayer) || false;
        itemInHierarchy.custom.isLayer = !isLayer;
        const newSequence = flattenHierarchy(hierarchyCopy);
        const newGroup = Object.assign(Object.assign({}, currentGroup), { children: newSequence });
        dispatch(upsertGroup({ group: newGroup }));
        yield dispatch(savePage());
    });
    const handleItemClone = (item) => __awaiter(void 0, void 0, void 0, function* () {
        const newTitle = `Copy of ${item.custom.sequenceName}`;
        const { payload: newActivity } = yield dispatch(createNewActivity({
            title: newTitle,
        }));
        const newSequenceEntry = {
            type: 'activity-reference',
            resourceId: newActivity.resourceId,
            activitySlug: newActivity.activitySlug,
            custom: Object.assign(Object.assign({}, item.custom), { sequenceId: `${newActivity.activitySlug}_${guid()}`, sequenceName: newTitle }),
        };
        const selectedActivity = allActivities.find((act) => act.id === item.resourceId);
        const copiedActivity = clone(selectedActivity);
        copiedActivity.id = newActivity.resourceId;
        copiedActivity.resourceId = newActivity.resourceId;
        copiedActivity.activitySlug = newActivity.activitySlug;
        copiedActivity.title = newTitle;
        dispatch(saveActivity({ activity: copiedActivity }));
        yield dispatch(upsertActivity({ activity: copiedActivity }));
        addNewSequence(newSequenceEntry, item.activitySlug);
    });
    const handleRenameItem = (item) => __awaiter(void 0, void 0, void 0, function* () {
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
        const newGroup = Object.assign(Object.assign({}, currentGroup), { children: newSequence });
        dispatch(upsertGroup({ group: newGroup }));
        yield dispatch(upsertActivity({ activity: activityClone }));
        yield dispatch(savePage());
        setItemToRename(undefined);
    });
    useEffect(() => {
        if (!itemToRename)
            return;
        const inputToFocus = document.getElementById('input-sequence-item-name');
        if (inputToFocus)
            inputToFocus.focus();
    }, [itemToRename]);
    const SequenceItemContextMenu = (props) => {
        var _a;
        const { id, item, index, arr, isParentQB } = props;
        const isBank = item.custom.isBank;
        const isLayer = item.custom.isLayer;
        const seqType = isLayer ? layerLabel : isBank ? bankLabel : screenLabel;
        return (<div className="dropdown aa-sequence-item-context-menu">
        {currentGroup && (<>
            <button className="dropdown-toggle aa-context-menu-trigger btn btn-link p-0 px-1" type="button" id={`sequence-item-${id}-context-trigger`} data-toggle="dropdown" aria-haspopup="true" aria-expanded="false" onClick={(e) => {
                    e.stopPropagation();
                    $(`#sequence-item-${id}-context-trigger`).dropdown('toggle');
                }}>
              <i className="fas fa-ellipsis-v"/>
            </button>
            <div id={`sequence-item-${id}-context-menu`} className="dropdown-menu" aria-labelledby={`sequence-item-${id}-context-trigger`}>
              {!isParentQB ? (<button className="dropdown-item" onClick={(e) => {
                        e.stopPropagation();
                        $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                        handleItemAdd(item);
                    }}>
                  <i className="fas fa-desktop mr-2"/> Add Subscreen
                </button>) : null}
              {!isBank && !isParentQB ? (<button className="dropdown-item" onClick={(e) => {
                        e.stopPropagation();
                        $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                        handleItemAdd(item, true);
                    }}>
                  <i className="fas fa-layer-group mr-2"/> Add Layer
                </button>) : null}
              {!isBank && !isParentQB ? (<button className="dropdown-item" onClick={(e) => {
                        e.stopPropagation();
                        $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                        handleItemAdd(item, false, true);
                    }}>
                  <i className="fas fa-cubes mr-2"/> Add Question Bank
                </button>) : null}
              {isLayer ? (<button className="dropdown-item" onClick={(e) => {
                        e.stopPropagation();
                        $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                        handleItemConvert(item);
                    }}>
                  <i className="fas fa-exchange-alt mr-2"/> Convert to Screen
                </button>) : !isBank && !isParentQB ? (<button className="dropdown-item" onClick={(e) => {
                        e.stopPropagation();
                        $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                        handleItemConvert(item);
                    }}>
                  <i className="fas fa-exchange-alt mr-2"/> Convert to Layer
                </button>) : null}
              <button className="dropdown-item" onClick={(e) => {
                    e.stopPropagation();
                    $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                    setItemToRename(item);
                }}>
                <i className="fas fa-i-cursor align-text-top mr-2"/> Rename
              </button>
              {!isLayer && !isBank && (<button className="dropdown-item" onClick={(e) => {
                        e.stopPropagation();
                        $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                        handleItemClone(item);
                    }}>
                  <i className="fas fa-clone align-text-top mr-2"/> {'Clone Screen'}
                </button>)}
              <button className="dropdown-item" onClick={(e) => {
                    e.stopPropagation();
                    $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                    navigator.clipboard.writeText(item.custom.sequenceId);
                }}>
                <i className="fas fa-clipboard align-text-top mr-2"/> {`Copy ${seqType} ID`}
              </button>
              {((_a = currentGroup === null || currentGroup === void 0 ? void 0 : currentGroup.children) === null || _a === void 0 ? void 0 : _a.length) > 1 && (<>
                  <div className="dropdown-divider"/>
                  <button className="dropdown-item text-danger" onClick={(e) => {
                        e.stopPropagation();
                        $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                        setShowConfirmDelete(true);
                        setItemToDelete(item);
                    }}>
                    <i className="fas fa-trash mr-2"/> Delete
                  </button>
                  <div className="dropdown-divider"></div>
                </>)}
              {index > 0 && (<button className="dropdown-item" onClick={(e) => {
                        e.stopPropagation();
                        $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                        handleItemReorder(e, item, ReorderDirection.UP);
                    }}>
                  <i className="fas fa-arrow-up mr-2"/> Move Up
                </button>)}
              {index < arr.length - 1 && (<button className="dropdown-item" onClick={(e) => {
                        e.stopPropagation();
                        $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                        handleItemReorder(e, item, ReorderDirection.DOWN);
                    }}>
                  <i className="fas fa-arrow-down mr-2"/> Move Down
                </button>)}
              {item.custom.layerRef && (<button className="dropdown-item" onClick={(e) => {
                        e.stopPropagation();
                        $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                        handleItemReorder(e, item, ReorderDirection.OUT);
                    }}>
                  <i className="fas fa-arrow-left mr-2"/> Move Out
                </button>)}
              {index > 0 && arr.length > 1 && (<button className="dropdown-item" onClick={(e) => {
                        e.stopPropagation();
                        $(`#sequence-item-${id}-context-menu`).dropdown('toggle');
                        handleItemReorder(e, item, ReorderDirection.IN);
                    }}>
                  <i className="fas fa-arrow-right mr-2"/> Move In
                </button>)}
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
          </>)}
      </div>);
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
    const getHierarchyList = (items, isParentQB = false) => items.map((item, index, arr) => {
        var _a;
        const title = ((_a = item.custom) === null || _a === void 0 ? void 0 : _a.sequenceName) || item.activitySlug;
        return (<Accordion key={`${index}`}>
            <ListGroup.Item as="li" className={`aa-sequence-item${item.children.length ? ' is-parent' : ''}`} key={`${item.custom.sequenceId}`} active={item.custom.sequenceId === currentSequenceId} onClick={(e) => handleItemClick(e, item)} tabIndex={0}>
              <div className="aa-sequence-details-wrapper">
                <div className="details">
                  {item.children.length ? (<ContextAwareToggle eventKey={`toggle_${item.custom.sequenceId}`} className={`aa-sequence-item-toggle`}/>) : null}
                  {!itemToRename ? (<span className="title" title={item.custom.sequenceId}>
                      {title}
                    </span>) : itemToRename.custom.sequenceId !== item.custom.sequenceId ? (<span className="title">{title}</span>) : null}
                  {itemToRename && (itemToRename === null || itemToRename === void 0 ? void 0 : itemToRename.custom.sequenceId) === item.custom.sequenceId && (<input id="input-sequence-item-name" className="form-control form-control-sm" type="text" placeholder={item.custom.isLayer ? 'Layer name' : 'Screen name'} value={itemToRename.custom.sequenceName} onClick={(e) => e.preventDefault()} onChange={(e) => setItemToRename(Object.assign(Object.assign({}, itemToRename), { custom: Object.assign(Object.assign({}, itemToRename.custom), { sequenceName: e.target.value }) }))} onFocus={(e) => e.target.select()} onBlur={() => handleRenameItem(item)} onKeyDown={(e) => {
                    if (e.key === 'Enter')
                        handleRenameItem(item);
                    if (e.key === 'Escape')
                        setItemToRename(undefined);
                }}/>)}
                  {item.custom.isLayer && (<i className="fas fa-layer-group ml-2 align-middle aa-isLayer"/>)}
                  {item.custom.isBank && (<i className="fas fa-cubes ml-2 align-middle aa-isLayer"/>)}
                </div>
                <SequenceItemContextMenu id={item.activitySlug} item={item} index={index} arr={arr} isParentQB={isParentQB}/>
              </div>
              {item.children.length ? (<Accordion.Collapse eventKey={`toggle_${item.custom.sequenceId}`}>
                  <ListGroup as="ol" className="aa-sequence nested">
                    {getHierarchyList(item.children, item.custom.isBank)}
                  </ListGroup>
                </Accordion.Collapse>) : null}
            </ListGroup.Item>
          </Accordion>);
    });
    return (<Accordion className="aa-sequence-editor" defaultActiveKey="0">
      <div className="aa-panel-section-title-bar">
        <div className="d-flex align-items-center">
          <ContextAwareToggle eventKey="0"/>
          <span className="title">Sequence Editor</span>
        </div>
        <OverlayTrigger placement="right" delay={{ show: 150, hide: 150 }} overlay={<Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
              New Sequence
            </Tooltip>}>
          <div className="dropdown">
            <button className="dropdown-toggle btn btn-link p-0" type="button" id="sequence-add" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
              <i className="fa fa-plus"/>
            </button>
            <div id="sequence-add-contextMenu" className="dropdown-menu" aria-labelledby="sequence-add-contextMenu">
              <button className="dropdown-item" onClick={() => {
            handleItemAdd(undefined);
        }}>
                <i className="fas fa-desktop mr-2"/> Screen
              </button>
              <button className="dropdown-item" onClick={() => {
            handleItemAdd(undefined, true);
        }}>
                <i className="fas fa-layer-group mr-2"/> Layer
              </button>
              <button className="dropdown-item" onClick={() => {
            handleItemAdd(undefined, false, true);
        }}>
                <i className="fas fa-cubes mr-2"/> Question Bank
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
      {showConfirmDelete && (<ConfirmDelete show={showConfirmDelete} elementType={((_a = itemToDelete.custom) === null || _a === void 0 ? void 0 : _a.isLayer)
                ? 'Layer'
                : ((_b = itemToDelete.custom) === null || _b === void 0 ? void 0 : _b.isBank)
                    ? 'Question Bank'
                    : 'Screen'} elementName={(_c = itemToDelete.custom) === null || _c === void 0 ? void 0 : _c.sequenceName} deleteHandler={() => handleItemDelete(itemToDelete)} cancelHandler={() => {
                setShowConfirmDelete(false);
                setItemToDelete(undefined);
            }}/>)}
    </Accordion>);
};
export default SequenceEditor;
//# sourceMappingURL=SequenceEditor.jsx.map