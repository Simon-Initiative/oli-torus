import { selectPaths, setRightPanelActiveTab } from 'apps/authoring/store/app/slice';
import { selectCurrentSelection, setCurrentSelection } from 'apps/authoring/store/parts/slice';
import { selectCurrentActivityTree } from 'apps/delivery/store/features/groups/selectors/deck';
import React, { useRef, useState } from 'react';
import { ListGroup, Overlay, OverlayTrigger, Popover, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { RightPanelTabs } from '../RightMenu/RightMenu';

const ComponentSearchContextMenu: React.FC = (props: any) => {
  const [show, setShow] = useState(false);
  const [target, setTarget] = useState(null);
  const ref = useRef(null);
  const paths = useSelector(selectPaths);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const dispatch = useDispatch();
  const currentPartSelection = useSelector(selectCurrentSelection);

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

  // TODO: allow parts to specify various icons in manifest
  const getPartIcon = (type: string) => {
    switch (type) {
      case 'janus-text-flow':
        return `${paths?.images}/icons/icon-text.svg`;
      case 'janus-image':
        return `${paths?.images}/icons/icon-image.svg`;
      case 'janus-video':
        return `${paths?.images}/icons/icon-video.svg`;
      case 'janus-audio':
        return `${paths?.images}/icons/icon-audio.svg`;
      case 'janus-mcq':
        return `${paths?.images}/icons/icon-multiChoice.svg`;
      case 'janus-navbutton':
        return `${paths?.images}/icons/icon-navButton.svg`;
      case 'janus-input-text':
        return `${paths?.images}/icons/icon-userInput.svg`;
    }
    // TODO: unknown icon?
    return `${paths?.images}/icons/icon-componentList.svg`;
  };

  console.log('ALL PARTS', { allParts, currentActivityTree });

  return (
    paths && (
      <div ref={ref}>
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
              <img src={`${paths.images}/icons/icon-componentList.svg`}></img>
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
                  >
                    <img title={part.type} src={getPartIcon(part.type)}></img>
                    <span>{part.id}</span>
                  </ListGroup.Item>
                ))}
              </ListGroup>
            </Popover.Content>
          </Popover>
        </Overlay>
      </div>
    )
  );
};

export default ComponentSearchContextMenu;
