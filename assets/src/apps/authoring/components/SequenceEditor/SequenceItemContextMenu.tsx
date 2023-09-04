/* eslint-disable react/no-unescaped-entities */
import React, { useEffect, useState } from 'react';
import { ListGroup, Toast } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { selectIsAdmin, selectProjectSlug } from 'apps/authoring/store/app/slice';

const layerLabel = 'Layer';
const bankLabel = 'Question Bank';
const screenLabel = 'Screen';
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
  const [showA, setShowA] = useState(false);
  const toggleShowA = () => {
    setShowA(!showA);
    props.contextMenuClicked(false);
  };
  useEffect(() => {
    setShowA(props.displayContextMenu);
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
        show={showA}
        onClose={toggleShowA}
        onMouseLeave={toggleShowA}
        style={{ cursor: 'pointer', left: '60px', top: '10%' }}
        className={`dropdown-menu ${props.show ? 'show' : ''}`}
      >
        <Toast.Body>
          <ListGroup variant="flush">
            {!isParentQB && (
              <ListGroup.Item className="dropdown-item">
                <i className="fas fa-desktop mr-2" /> Add Subscreen
              </ListGroup.Item>
            )}
            {!isBank && !isParentQB && (
              <ListGroup.Item className="dropdown-item">
                <i className="fas fa-layer-group mr-2" /> Add Layer
              </ListGroup.Item>
            )}
            {!isBank && !isParentQB && (
              <ListGroup.Item className="dropdown-item">
                <i className="fas fa-cubes mr-2" /> Add Question Bank
              </ListGroup.Item>
            )}
            {isLayer ? (
              <ListGroup.Item className="dropdown-item">
                <i className="fas fa-exchange-alt mr-2" /> Convert to Screen
              </ListGroup.Item>
            ) : !isBank && !isParentQB ? (
              <ListGroup.Item className="dropdown-item">
                <i className="fas fa-exchange-alt mr-2" /> Convert to Layer
              </ListGroup.Item>
            ) : null}
            <ListGroup.Item className="dropdown-item">
              <i className="fas fa-i-cursor align-text-top mr-2" /> Rename
            </ListGroup.Item>
            {!isLayer && !isBank && (
              <ListGroup.Item className="dropdown-item">
                <i className="fas fa-clone align-text-top mr-2" /> Clone Screen
              </ListGroup.Item>
            )}
            <ListGroup.Item className="dropdown-item">
              <i className="fas fa-clipboard align-text-top mr-2" /> {`Copy  ID`}
            </ListGroup.Item>
            <ListGroup.Item className="dropdown-item">
              <i className="fas fa-trash mr-2" /> Delete
            </ListGroup.Item>

            <div style={{ borderBottomWidth: '2px', marginTop: '10px' }}></div>
            {index > 0 && (
              <ListGroup.Item className="dropdown-item">
                <i className="fas fa-arrow-up mr-2" /> Move Up
              </ListGroup.Item>
            )}
            {arr && index < arr.length - 1 && (
              <ListGroup.Item className="dropdown-item">
                <i className="fas fa-arrow-down mr-2" /> Move Down
              </ListGroup.Item>
            )}
            {item?.custom?.layerRef && (
              <ListGroup.Item className="dropdown-item">
                <i className="fas fa-arrow-left mr-2" /> Move Out
              </ListGroup.Item>
            )}
            {arr && index > 0 && arr?.length > 1 && (
              <>
                <ListGroup.Item className="dropdown-item">
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
