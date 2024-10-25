/* eslint-disable react/no-unescaped-entities */
import React, { useEffect, useRef, useState } from 'react';
import { ListGroup, Toast } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { selectIsAdmin, selectProjectSlug } from 'apps/authoring/store/app/slice';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
  SequenceEntryType,
  SequenceHierarchyItem,
} from 'apps/delivery/store/features/groups/actions/sequence';

const layerLabel = 'Layer';
const bankLabel = 'Question Bank';
const screenLabel = 'Screen';
enum ReorderDirection {
  UP = 0,
  DOWN,
  IN,
  OUT,
}
const SequenceItemContextMenu = (props: any) => {
  const [isBank, setIsBank] = useState(false);
  const [isLayer, setIsLayer] = useState<any>();
  const [seqType, setSeqType] = useState<any>();
  const isAdmin = useSelector(selectIsAdmin);
  const [id, setId] = useState(false);
  const [item, setItem] = useState<any>();
  const [index, setIndex] = useState<any>();
  const [arr, setArr] = useState<any>();
  const [isParentQB, setIsParentQB] = useState();
  const projectSlug = useSelector(selectProjectSlug);
  const [showMenu, setShowMenu] = useState(false);
  const dispatch = useDispatch();
  function useOutsideAlerter(ref: any) {
    useEffect(() => {
      /**
       * Close context menu if clicked on outside of element
       */
      function handleClickOutside(event: any) {
        if (ref.current && !ref.current.contains(event.target)) {
          setShowMenu(false);
        }
      }
      // Bind the event listener
      document.addEventListener('mousedown', handleClickOutside);
      return () => {
        // Unbind the event listener on clean up
        document.removeEventListener('mousedown', handleClickOutside);
      };
    }, [ref]);
  }

  const wrapperRef = useRef(null);
  useOutsideAlerter(wrapperRef);

  const handleItemAdd = async (
    parentItem: SequenceEntry<SequenceEntryChild> | undefined,
    isLayer = false,
    isBank = false,
  ) => {
    const details = { event: 'handleItemAdd', parentItem, isLayer, isBank };
    props.onMenuItemClick(details);
    props.contextMenuClicked(false);
  };

  const handleItemReorder = async (
    event: any,
    item: SequenceHierarchyItem<SequenceEntryType>,
    direction: ReorderDirection,
  ) => {
    const details = { event: 'handleItemReorder', item, direction };
    props.onMenuItemClick(details);
    props.contextMenuClicked(false);
  };

  const handleItemDelete = async (item: SequenceHierarchyItem<SequenceEntryType>) => {
    const details = { event: 'handleItemDelete', item };
    props.onMenuItemClick(details);
    props.contextMenuClicked(false);
  };

  const handleItemConvert = async (item: SequenceHierarchyItem<SequenceEntryType>) => {
    const details = { event: 'handleItemConvert', item };
    props.onMenuItemClick(details);
    props.contextMenuClicked(false);
  };

  const handleItemClone = async (item: SequenceHierarchyItem<SequenceEntryType>) => {
    const details = { event: 'handleItemClone', item };
    props.onMenuItemClick(details);
    props.contextMenuClicked(false);
  };
  const handleRenameItem = async (item: any) => {
    dispatch(setCurrentPartPropertyFocus({ focus: false }));
    const details = { event: 'setItemToRename', item };
    props.onMenuItemClick(details);
    props.contextMenuClicked(false);
  };

  const handleCopyItem = async (item: any) => {
    setShowMenu(false);
    props.contextMenuClicked(false);
    navigator.clipboard.writeText(item.custom.sequenceId);
  };

  useEffect(() => {
    setShowMenu(props.displayContextMenu);
    if (props.sequenceItemDetails) {
      const sequenceItemDetail = props.sequenceItemDetails;
      setId(sequenceItemDetail.id);
      setItem(sequenceItemDetail.item);
      setIndex(sequenceItemDetail.index);
      setArr(sequenceItemDetail.arr);
      setIsParentQB(sequenceItemDetail.isParentQB);
      setIsBank(sequenceItemDetail.item.custom.isBank);
      setIsLayer(sequenceItemDetail.item.custom.isLayer);
      setSeqType(isLayer ? layerLabel : isBank ? bankLabel : screenLabel);
    }
  }, [props]);

  return (
    <>
      <Toast
        id={`context-menu-${id}`}
        ref={wrapperRef}
        show={showMenu}
        style={{ cursor: 'pointer', left: '60px', top: '10%' }}
        className={`dropdown-menu ${props.show ? 'show' : ''}`}
      >
        <Toast.Body>
          <ListGroup variant="flush">
            {!isParentQB && (
              <ListGroup.Item className="dropdown-item" onClick={() => handleItemAdd(item)}>
                <i className="fas fa-desktop mr-2" /> Add Subscreen
              </ListGroup.Item>
            )}
            {!isBank && !isParentQB && (
              <ListGroup.Item className="dropdown-item" onClick={() => handleItemAdd(item, true)}>
                <i className="fas fa-layer-group mr-2" /> Add Layer
              </ListGroup.Item>
            )}
            {!isBank && !isParentQB && (
              <ListGroup.Item
                className="dropdown-item"
                onClick={() => handleItemAdd(item, false, true)}
              >
                <i className="fas fa-cubes mr-2" /> Add Question Bank
              </ListGroup.Item>
            )}
            {isLayer ? (
              <ListGroup.Item className="dropdown-item" onClick={() => handleItemConvert(item)}>
                <i className="fas fa-exchange-alt mr-2" /> Convert to Screen
              </ListGroup.Item>
            ) : !isBank && !isParentQB ? (
              <ListGroup.Item className="dropdown-item" onClick={() => handleItemConvert(item)}>
                <i className="fas fa-exchange-alt mr-2" /> Convert to Layer
              </ListGroup.Item>
            ) : null}
            <ListGroup.Item className="dropdown-item" onClick={() => handleRenameItem(item)}>
              <i className="fas fa-i-cursor align-text-top mr-2" /> Rename
            </ListGroup.Item>
            {!isLayer && !isBank && (
              <ListGroup.Item className="dropdown-item" onClick={() => handleItemClone(item)}>
                <i className="fas fa-clone align-text-top mr-2" /> Clone Screen
              </ListGroup.Item>
            )}
            <ListGroup.Item className="dropdown-item" onClick={() => handleCopyItem(item)}>
              <i className="fas fa-clipboard align-text-top mr-2" /> {`Copy ${seqType} ID`}
            </ListGroup.Item>
            <ListGroup.Item className="dropdown-item" onClick={() => handleItemDelete(item)}>
              <i className="fas fa-trash mr-2" /> Delete
            </ListGroup.Item>

            <div style={{ borderBottomWidth: '2px', marginTop: '10px' }}></div>
            {index > 0 && (
              <ListGroup.Item
                className="dropdown-item"
                onClick={(e) => handleItemReorder(e, item, ReorderDirection.UP)}
              >
                <i className="fas fa-arrow-up mr-2" /> Move Up
              </ListGroup.Item>
            )}
            {arr && index < arr.length - 1 && (
              <ListGroup.Item
                className="dropdown-item"
                onClick={(e) => handleItemReorder(e, item, ReorderDirection.DOWN)}
              >
                <i className="fas fa-arrow-down mr-2" /> Move Down
              </ListGroup.Item>
            )}
            {item?.custom?.layerRef && (
              <ListGroup.Item
                className="dropdown-item"
                onClick={(e) => handleItemReorder(e, item, ReorderDirection.OUT)}
              >
                <i className="fas fa-arrow-left mr-2" /> Move Out
              </ListGroup.Item>
            )}
            {arr && index > 0 && arr?.length > 1 && (
              <>
                <ListGroup.Item
                  className="dropdown-item"
                  onClick={(e) => handleItemReorder(e, item, ReorderDirection.IN)}
                >
                  <i className="fas fa-arrow-right mr-2" /> Move In
                </ListGroup.Item>
              </>
            )}

            {isAdmin && (
              <>
                {' '}
                <div style={{ borderBottomWidth: '2px', marginTop: '10px' }} />
                <ListGroup.Item
                  onClick={() => {
                    // open revision history in new tab
                    window.open(`/project/${projectSlug}/history/resource_id/${item.resourceId}`);
                  }}
                >
                  <i className="fas fa-history mr-2" /> Revision History (Admin)
                </ListGroup.Item>
                <div style={{ borderBottomWidth: '2px', marginTop: '10px' }} />
              </>
            )}
          </ListGroup>
        </Toast.Body>
      </Toast>
    </>
  );
};

export default SequenceItemContextMenu;
