import {
  selectPartComponentTypes,
  selectPaths,
  setRightPanelActiveTab,
} from 'apps/authoring/store/app/slice';
import { selectCurrentSelection, setCurrentSelection } from 'apps/authoring/store/parts/slice';
import { selectCurrentActivityTree } from 'apps/delivery/store/features/groups/selectors/deck';
import React, { useState } from 'react';
import { ListGroup, Overlay, OverlayTrigger, Popover, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { RightPanelTabs } from '../RightMenu/RightMenu';

const ComponentSearchContextMenu: React.FC = () => {
  const [show, setShow] = useState(false);
  const [target, setTarget] = useState(null);
  const paths = useSelector(selectPaths);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const dispatch = useDispatch();
  const currentPartSelection = useSelector(selectCurrentSelection);
  const availablePartComponents = useSelector(selectPartComponentTypes);

  const handleClick = (event: any) => {
    setShow(!show);
    setTarget(event.target);
  };

  const allParts = (currentActivityTree || []).reduce(
    (acc, activity) => acc.concat(activity.content.partsLayout || []),
    [],
  );

  const handlePartClick = (part: any) => {
    setShow(!show);
    dispatch(setCurrentSelection({ selection: part.id }));
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.COMPONENT }));
  };

  const getPartIcon = (type: string) => {
    const part = availablePartComponents.find((part) => part.delivery_element === type);
    if (!part) {
      return `${paths?.images}/icons/icon-componentList.svg`;
    }
    // TODO: test if part.icon starts with http and if so use that instead of the paths.images
    return `${paths?.images}/icons/${part.icon}`;
  };

  console.log('ALL PARTS', { allParts, currentActivityTree });

  return (
    paths && (
      <>
        <OverlayTrigger
          placement="bottom"
          delay={{ show: 150, hide: 150 }}
          overlay={
            <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
              Find Components
            </Tooltip>
          }
        >
          <span>
            <button className="px-2 btn btn-link" onClick={handleClick}>
              <img src={`${paths.images}/icons/icon-findComponents.svg`}></img>
            </button>
          </span>
        </OverlayTrigger>

        <Overlay
          show={show}
          target={target}
          placement="bottom"
          container={document.getElementById('advanced-authoring')}
          containerPadding={20}
        >
          <Popover id="search-popover">
            <Popover.Title as="h3">{allParts.length} Parts On Screen</Popover.Title>
            <Popover.Content>
              <ListGroup className="aa-parts-list">
                {allParts.map((part: any) => (
                  <ListGroup.Item
                    active={part.id === currentPartSelection}
                    action
                    onClick={() => handlePartClick(part)}
                    key={part.id}
                    className="d-flex align-items-center"
                  >
                    <div className="text-center mr-1 d-inline-block" style={{ minWidth: '36px' }}>
                      <img title={part.type} src={getPartIcon(part.type)} />
                    </div>
                    <span className="mr-2">{part.id}</span>
                  </ListGroup.Item>
                ))}
              </ListGroup>
            </Popover.Content>
          </Popover>
        </Overlay>
      </>
    )
  );
};

export default ComponentSearchContextMenu;
