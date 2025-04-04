import React, { useState } from 'react';
import { useCallback } from 'react';
import { ListGroup, Overlay, OverlayTrigger, Popover, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import cloneDeep from 'lodash/cloneDeep';
import { saveActivity } from 'apps/authoring/store/activities/actions/saveActivity';
import {
  selectPartComponentTypes,
  selectPaths,
  setRightPanelActiveTab,
} from 'apps/authoring/store/app/slice';
import { selectCurrentSelection, setCurrentSelection } from 'apps/authoring/store/parts/slice';
import { selectCurrentActivityTree } from 'apps/delivery/store/features/groups/selectors/deck';
import { IPartLayout } from '../../../delivery/store/features/activities/slice';
import { ReorderingIcon } from '../Flowchart/toolbar/ReorderingIcon';
import { RightPanelTabs } from '../RightMenu/RightMenu';

const ComponentSearchContextMenu: React.FC<{
  authoringContainer: React.RefObject<HTMLElement>;
  basicAuthoring?: boolean;
}> = ({ authoringContainer, basicAuthoring }) => {
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

  // TODO: tag parent items so that we can mark them instead?
  const allParts = (currentActivityTree || [])
    .slice(-1)
    .reduce(
      (acc, activity) => acc.concat(activity.content?.partsLayout || []),
      [] as IPartLayout[],
    );

  const handlePartClick = useCallback(
    (part: any) => {
      const [currentActivity] = currentActivityTree?.slice(-1) || [];
      if (!currentActivity) {
        return;
      }
      if ((currentActivity.content?.partsLayout || []).find((p: any) => p.id === part.id)) {
        setShow(!show);
        dispatch(setCurrentSelection({ selection: part.id }));
        dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.COMPONENT }));
      }
    },
    [currentActivityTree],
  );

  const getPartIcon = (type: string) => {
    const part = availablePartComponents.find((part) => part.delivery_element === type);
    if (!part) {
      return `${paths?.images}/icons/icon-componentList.svg`;
    }
    // TODO: test if part.icon starts with http and if so use that instead of the paths.images
    return `${paths?.images}/icons/${part.icon}`;
  };

  const updateActivityTreeParts = (list: any) => {
    const activity = cloneDeep((currentActivityTree || []).slice(-1)[0]);
    if (activity.content) {
      activity.content.partsLayout = list;
    }
    dispatch(saveActivity({ activity, undoable: true, immediate: true }));
  };

  const moveComponentUp = (event: any, part: any, index: number) => {
    event.preventDefault();
    event.stopPropagation();
    const list = allParts.filter((p: any) => p.id !== part.id);
    list.splice(index - 1, 0, part);

    updateActivityTreeParts(list);
  };

  const moveComponentDown = (event: any, part: any, index: number) => {
    event.preventDefault();
    event.stopPropagation();
    const list = allParts.filter((p: any) => p.id !== part.id);
    list.splice(index + 1, 0, part);

    updateActivityTreeParts(list);
  };

  // console.log('ALL PARTS', { allParts, currentActivityTree });

  return (
    paths && (
      <>
        <OverlayTrigger
          placement="bottom"
          delay={{ show: 150, hide: 150 }}
          overlay={
            <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
              {basicAuthoring
                ? 'Reorder components to set the reading order for screen readers.'
                : 'Find Components'}
            </Tooltip>
          }
        >
          {basicAuthoring ? (
            <span style={{ cursor: 'pointer' }} onClick={handleClick}>
              <ReorderingIcon></ReorderingIcon>
            </span>
          ) : (
            <span>
              <button className="px-2 btn btn-link" onClick={handleClick}>
                <img src={`${paths.images}/icons/icon-findComponents.svg`}></img>
              </button>
            </span>
          )}
        </OverlayTrigger>

        <Overlay
          show={show}
          target={target}
          placement="bottom"
          container={authoringContainer.current}
          containerPadding={20}
          rootClose={true}
          onHide={() => setShow(false)}
        >
          <Popover id="search-popover">
            <Popover.Title as="h3">{allParts.length} Parts On Screen</Popover.Title>
            <Popover.Content>
              <ListGroup className="aa-parts-list">
                {allParts.map((part: any, index: number) => (
                  <ListGroup.Item
                    active={part.id === currentPartSelection}
                    action
                    onClick={() => handlePartClick(part)}
                    key={part.id}
                    className="d-flex w-full align-items-center justify-content-between"
                  >
                    <div className="text-center mr-1 d-inline-block" style={{ minWidth: '36px' }}>
                      <img title={part.type} src={getPartIcon(part.type)} />
                      <span className="mr-2">{part.id}</span>
                    </div>

                    <div className="text-center mr-1 d-flex" style={{ minWidth: '36px' }}>
                      <button
                        className="btn btn-xs move-btn"
                        onClick={(ev) => moveComponentUp(ev, part, index)}
                        disabled={index === 0}
                      >
                        <span className="icon-chevron-up" />
                        <span className="sr-only">Move Up</span>
                      </button>
                      <button
                        className="btn btn-xs move-btn"
                        onClick={(ev) => moveComponentDown(ev, part, index)}
                        disabled={index === allParts.length - 1}
                      >
                        <span className="icon-chevron-down" />
                        <span className="sr-only">Move Down</span>
                      </button>
                    </div>
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
