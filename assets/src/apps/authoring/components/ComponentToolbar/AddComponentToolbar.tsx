import React, { Fragment, useCallback, useEffect, useState } from 'react';
import { ListGroup, Overlay, OverlayTrigger, Popover, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import {
  selectCopiedPart,
  selectCopiedPartActivityId,
  selectPartComponentTypes,
  selectPaths,
  setCopiedPart,
  setRightPanelActiveTab,
} from 'apps/authoring/store/app/slice';
import { addPart } from 'apps/authoring/store/parts/actions/addPart';
import {
  selectCurrentPartPropertyFocus,
  setCurrentSelection,
} from 'apps/authoring/store/parts/slice';
import {
  selectCurrentActivityTree,
  selectCurrentSequenceId,
  selectSequence,
} from 'apps/delivery/store/features/groups/selectors/deck';
import { useKeyDown } from 'hooks/useKeyDown';
import guid from 'utils/guid';
import { RightPanelTabs } from '../RightMenu/RightMenu';

const defaultFrequentlyUsed = [
  'janus_text_flow',
  'janus_image',
  'janus_mcq',
  'janus_video',
  'janus_input_text',
  'janus_capi_iframe',
];

const AddComponentToolbar: React.FC<{
  authoringContainer: React.RefObject<HTMLElement>;
  frequentlyUsed?: string[];
  showMoreComponentsMenu?: boolean;
  disabled?: boolean;
  showPasteComponentOption?: boolean;
}> = ({
  authoringContainer,
  frequentlyUsed,
  showMoreComponentsMenu,
  disabled,
  showPasteComponentOption,
}) => {
  const dispatch = useDispatch();
  const paths = useSelector(selectPaths);
  const imgsPath = paths?.images || '';

  const [showPartsMenu, setShowPartsMenu] = useState(false);
  const [partsMenuTarget, setPartsMenuTarget] = useState(null);
  const availablePartComponents = useSelector(selectPartComponentTypes);
  const copiedPartActivityId = useSelector(selectCopiedPartActivityId);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentSequence = useSelector(selectSequence);
  const currentSequenceId = useSelector(selectCurrentSequenceId);
  const copiedPart = useSelector(selectCopiedPart);
  const [newPartAddOffset, setNewPartAddOffset] = useState<number>(0);
  const addPartToCurrentScreen = (newPartData: any) => {
    if (currentActivityTree) {
      const [currentActivity] = currentActivityTree.slice(-1);
      dispatch(addPart({ activityId: currentActivity.id, newPartData }));
    }
  };
  const _currentPartPropertyFocus = useSelector(selectCurrentPartPropertyFocus);
  useEffect(() => {
    setNewPartAddOffset(0);
  }, [currentSequenceId]);

  const handleAddComponent = useCallback(
    (partComponentType: string) => {
      setShowPartsMenu(false);
      if (!availablePartComponents) {
        return;
      }
      const partComponent = availablePartComponents.find((p) => p.slug === partComponentType);
      if (!partComponent) {
        console.warn(`No part ${partComponentType} found in registry!`, {
          availablePartComponents,
        });
        return;
      }
      const PartClass = customElements.get(partComponent.authoring_element);
      if (PartClass) {
        const defaultNewPartWidth = 100;
        const defaultNewPartHeight = 100;
        // only ever add to the current  activity, not a layer
        setNewPartAddOffset(newPartAddOffset + 1);
        const part = new PartClass() as any;
        const newPartData = {
          id: `${partComponentType}-${guid()}`,
          type: partComponent.delivery_element,
          custom: {
            x: 10 * newPartAddOffset, // when new components are added, offset the location placed by 10 px
            y: 10 * newPartAddOffset, // when new components are added, offset the location placed by 10 px
            z: 0,
            width: defaultNewPartWidth,
            height: defaultNewPartHeight,
          },
        };
        const creationContext = { transform: { ...newPartData.custom } };
        if (part.createSchema) {
          newPartData.custom = { ...newPartData.custom, ...part.createSchema(creationContext) };
        }
        addPartToCurrentScreen(newPartData);
      }
    },
    [availablePartComponents, currentActivityTree, currentSequence, newPartAddOffset],
  );

  const handlePartMenuButtonClick = (event: any) => {
    setShowPartsMenu(!showPartsMenu);
    setPartsMenuTarget(event.target);
  };
  const handlePartPasteClick = () => {
    //When a part is pasted, offset the new part component by 20px from the original part
    const pasteOffset = 20;
    let newPartData = {
      id: `${copiedPart.type}-${guid()}`,
      type: copiedPart.type,
      custom: copiedPart.custom,
    };
    if (currentActivityTree) {
      const [currentActivity] = currentActivityTree.slice(-1);
      console.log({ copiedPartActivityId, currentActivityId: currentActivity.id });
      if (copiedPartActivityId === currentActivity.id) {
        newPartData = {
          id: `${copiedPart.type}-${guid()}`,
          type: copiedPart.type,
          custom: {
            ...copiedPart.custom,
            x: copiedPart.custom.x + pasteOffset,
            y: copiedPart.custom.y + pasteOffset,
          },
        };
      }
    }
    addPartToCurrentScreen(newPartData);
    dispatch(setCurrentSelection({ selection: newPartData.id }));

    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.COMPONENT }));
    dispatch(setCopiedPart({ copiedPart: null }));
  };

  useKeyDown(
    () => {
      if (copiedPart && _currentPartPropertyFocus) {
        handlePartPasteClick();
      }
    },
    ['KeyV'],
    { ctrlKey: true },
    [copiedPart, currentActivityTree, _currentPartPropertyFocus],
  );

  return (
    <Fragment>
      {availablePartComponents
        .filter((part) => frequentlyUsed!.includes(part.slug))
        .sort((a, b) => {
          const aIndex = frequentlyUsed!.indexOf(a.slug);
          const bIndex = frequentlyUsed!.indexOf(b.slug);
          return aIndex - bIndex;
        })
        .map((part) => (
          <OverlayTrigger
            key={part.slug}
            placement="bottom"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                <strong>{part.title}</strong>
                <br />
                <em>{part.description}</em>
              </Tooltip>
            }
          >
            <span>
              <button
                disabled={disabled}
                className="px-2 btn btn-link"
                onClick={() => handleAddComponent(part.slug)}
              >
                <img src={`${imgsPath}/icons/${part.icon}`}></img>
              </button>
            </span>
          </OverlayTrigger>
        ))}
      {showPasteComponentOption && copiedPart ? (
        <OverlayTrigger
          placement="bottom"
          delay={{ show: 150, hide: 150 }}
          overlay={
            <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
              Paste Component
            </Tooltip>
          }
        >
          <span>
            <button className="px-2 btn btn-link" onClick={handlePartPasteClick}>
              <img src={`${imgsPath}/icons/icon-paste.svg`} width="30px"></img>
            </button>
          </span>
        </OverlayTrigger>
      ) : null}
      {showMoreComponentsMenu && (
        <>
          <OverlayTrigger
            placement="bottom"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                More Components
              </Tooltip>
            }
          >
            <span>
              <button className="px-2 btn btn-link" onClick={handlePartMenuButtonClick}>
                <img src={`${imgsPath}/icons/icon-componentList.svg`}></img>
              </button>
            </span>
          </OverlayTrigger>

          <Overlay
            show={showPartsMenu}
            target={partsMenuTarget}
            placement="bottom"
            container={authoringContainer}
            containerPadding={20}
            rootClose={true}
            onHide={() => setShowPartsMenu(false)}
          >
            <Popover id="moreComponents-popover">
              <Popover.Title as="h3">More Components</Popover.Title>
              <Popover.Content>
                <ListGroup className="aa-parts-list">
                  {availablePartComponents
                    .filter(
                      (part) =>
                        !frequentlyUsed!.includes(part.slug) && part.slug !== 'janus_hub_spoke', // hub Spoke is only for basic authoring
                    )
                    .map((part) => (
                      <ListGroup.Item
                        action
                        onClick={() => handleAddComponent(part.slug)}
                        key={part.slug}
                        className="d-flex align-items-center"
                      >
                        <div
                          className="text-center mr-1 d-inline-block"
                          style={{ minWidth: '36px' }}
                        >
                          <img title={part.description} src={`${imgsPath}/icons/${part.icon}`} />
                        </div>
                        <span className="mr-3">{part.title}</span>
                      </ListGroup.Item>
                    ))}
                </ListGroup>
              </Popover.Content>
            </Popover>
          </Overlay>
        </>
      )}
    </Fragment>
  );
};

AddComponentToolbar.defaultProps = {
  frequentlyUsed: defaultFrequentlyUsed,
  showMoreComponentsMenu: true,
  disabled: false,
  showPasteComponentOption: true,
};

export default AddComponentToolbar;
