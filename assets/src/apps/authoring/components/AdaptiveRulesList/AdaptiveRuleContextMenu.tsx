/* eslint-disable react/no-unescaped-entities */
import React, { useEffect, useRef, useState } from 'react';
import { ListGroup, Toast } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { selectSequenceEditorExpanded } from 'apps/authoring/store/app/slice';
import { selectCopiedItem, selectCopiedType } from 'apps/authoring/store/clipboard/slice';
import { IAdaptiveRule, InitState } from 'apps/delivery/store/features/activities/slice';

const AdaptiveRuleContextMenu = (props: any) => {
  const [id, setId] = useState(false);
  const [item, setItem] = useState<any>();
  const [index, setIndex] = useState<any>();
  const [arr, setArr] = useState<any>();
  const [showMenu, setShowMenu] = useState(false);
  const copied = useSelector(selectCopiedItem);
  const copiedType = useSelector(selectCopiedType);
  const [clientY, setClientY] = useState<number>(0);
  const sequenceEditorExpanded = useSelector(selectSequenceEditorExpanded);
  function useOutsideAlerter(ref: any) {
    useEffect(() => {
      /**
       * Close context menu if clicked on outside of element
       */
      function handleClickOutside(event: any) {
        if (ref.current && !ref.current.contains(event.target)) {
          setShowMenu(false);
          props.contextMenuClicked(false);
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

  const handleRuleReorder = async (index: number, direction: any) => {
    const details = { event: 'handleRuleReorder', index, direction };
    props.onMenuItemClick(details);
    props.contextMenuClicked(false);
  };

  const handleRulePaste = async (
    copied: IAdaptiveRule | InitState,
    copiedType: any,
    index: any,
  ) => {
    const details = { event: 'handleRulePaste', item: copied, type: copiedType, index };
    props.onMenuItemClick(details);
    props.contextMenuClicked(false);
  };

  const handleRenameRule = async (item: IAdaptiveRule) => {
    const details = { event: 'handleRenameRule', item };
    props.onMenuItemClick(details);
    props.contextMenuClicked(false);
  };

  const handleCopyRule = async (rule: IAdaptiveRule | 'initState') => {
    const details = { event: 'handleCopyRule', rule };
    props.onMenuItemClick(details);
    props.contextMenuClicked(false);
  };

  const handleDuplicateRule = async (rule: IAdaptiveRule, index: number) => {
    const details = { event: 'handleDuplicateRule', rule, index };
    props.onMenuItemClick(details);
    props.contextMenuClicked(false);
  };

  const handleItemDelete = async (item: IAdaptiveRule) => {
    const details = { event: 'handleItemDelete', item };
    props.onMenuItemClick(details);
    props.contextMenuClicked(false);
  };

  useEffect(() => {
    setShowMenu(props.displayContextMenu);

    if (props.adaptiveRuleDetails) {
      const { rule, clientY } = props.adaptiveRuleDetails;
      const adaptiveRuleDetail = rule;
      setId(adaptiveRuleDetail.id);
      setItem(adaptiveRuleDetail.item);
      setIndex(adaptiveRuleDetail.index);
      setArr(adaptiveRuleDetail.arr);
      setClientY(clientY);
    }
  }, [props]);

  return (
    <>
      <Toast
        id={`rule-list-item-${id}-context-trigger`}
        ref={wrapperRef}
        show={showMenu}
        style={{
          cursor: 'pointer',
          left: '70px',
          bottom: sequenceEditorExpanded ? `1px` : `auto`,
          top: sequenceEditorExpanded ? `auto` : `${clientY - 30}px`,
        }}
        className={`dropdown-menu ${props.show ? 'show' : ''}`}
      >
        <Toast.Body>
          {item && (
            <ListGroup variant="flush">
              {item !== 'initState' && (
                <ListGroup.Item className="dropdown-item" onClick={() => handleRenameRule(item)}>
                  <i className="fas fa-i-cursor align-text-top mr-2" /> Rename
                </ListGroup.Item>
              )}
              {(item === 'initState' || !item.default || (item.default && item.correct)) && (
                <>
                  <ListGroup.Item className="dropdown-item" onClick={() => handleCopyRule(item)}>
                    <i className="fas fa-copy mr-2" /> Copy
                  </ListGroup.Item>
                  <ListGroup.Item
                    className="dropdown-item"
                    onClick={() => handleRulePaste(copied, copiedType, index)}
                  >
                    <i className="fas fa-clipboard mr-2" /> Insert copied rule
                  </ListGroup.Item>
                </>
              )}

              {item !== 'initState' && index !== 'initState' && (
                <>
                  {!item.default && (
                    <>
                      <ListGroup.Item
                        className="dropdown-item"
                        onClick={() => handleRuleReorder(index, 'down')}
                      >
                        <i className="fas fa-arrow-down mr-2" />
                        Move Down
                      </ListGroup.Item>{' '}
                      <div style={{ borderBottomWidth: '2px', marginTop: '10px' }} />
                      <ListGroup.Item
                        className="dropdown-item"
                        onClick={() => handleDuplicateRule(item, index)}
                      >
                        <i className="fas fa-copy mr-2" /> Duplicate
                      </ListGroup.Item>
                      <ListGroup.Item
                        className="dropdown-item"
                        onClick={() => handleItemDelete(item)}
                      >
                        <i className="fas fa-trash mr-2" /> Delete
                      </ListGroup.Item>
                      <div className="dropdown-divider"></div>
                    </>
                  )}
                  {index > 1 && !item.default && (
                    <ListGroup.Item
                      className="dropdown-item"
                      onClick={() => handleRuleReorder(index, 'up')}
                    >
                      <i className="fas fa-arrow-up mr-2" /> Move Up
                    </ListGroup.Item>
                  )}
                  {arr && index < arr.length - 2 && !item.default && (
                    <>
                      <div style={{ borderBottomWidth: '2px', marginTop: '10px' }} />
                      <ListGroup.Item
                        className="dropdown-item"
                        onClick={() => handleRuleReorder(index, 'down')}
                      >
                        <i className="fas fa-arrow-down mr-2" /> Move Down
                      </ListGroup.Item>
                    </>
                  )}
                </>
              )}
            </ListGroup>
          )}
        </Toast.Body>
      </Toast>
    </>
  );
};

export default AdaptiveRuleContextMenu;
