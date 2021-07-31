import { selectPaths } from 'apps/authoring/store/app/slice';
import { setCurrentSelection } from 'apps/authoring/store/parts/slice';
import { selectCurrentActivityTree } from 'apps/delivery/store/features/groups/selectors/deck';
import React, { useRef, useState } from 'react';
import { ListGroup, Overlay, OverlayTrigger, Popover, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';

const ComponentSearchContextMenu: React.FC = (props: any) => {
  const [show, setShow] = useState(false);
  const [target, setTarget] = useState(null);
  const ref = useRef(null);
  const paths = useSelector(selectPaths);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const dispatch = useDispatch();

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
  };

  console.log('ALL PARTS', { allParts, currentActivityTree });

  return paths && (
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
            <ListGroup>
              {allParts.map((part: any) => (
                <ListGroup.Item action onClick={() => handlePartClick(part)} key={part.id}>
                  {part.id}
                </ListGroup.Item>
              ))}
            </ListGroup>
          </Popover.Content>
        </Popover>
      </Overlay>
    </div>
  );
};

export default ComponentSearchContextMenu;
