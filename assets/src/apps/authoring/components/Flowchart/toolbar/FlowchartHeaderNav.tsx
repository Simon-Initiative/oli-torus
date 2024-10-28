import React, { useCallback, useEffect, useRef, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { setCurrentSelection } from 'apps/authoring/store/parts/slice';
import { useKeyDown } from 'hooks/useKeyDown';
import useHover from '../../../../../components/hooks/useHover';
import guid from '../../../../../utils/guid';
import {
  IActivity,
  selectAllActivities,
  selectCurrentActivity,
} from '../../../../delivery/store/features/activities/slice';
import {
  selectCurrentActivityTree,
  selectCurrentSequenceId,
  selectSequence,
} from '../../../../delivery/store/features/groups/selectors/deck';
import {
  selectCopiedPart,
  selectPartComponentTypes,
  selectPaths,
  selectProjectSlug,
  selectRevisionSlug,
  setCopiedPart,
  setRightPanelActiveTab,
  setShowScoringOverview,
} from '../../../store/app/slice';
import { redo } from '../../../store/history/actions/redo';
import { undo } from '../../../store/history/actions/undo';
import { selectHasRedo, selectHasUndo } from '../../../store/history/slice';
import { addPart } from '../../../store/parts/actions/addPart';
import { RightPanelTabs } from '../../RightMenu/RightMenu';
import { verifyFlowchartLesson } from '../flowchart-actions/verify-flowchart-lesson';
import { getScreenQuestionType } from '../paths/path-options';
import { validateScreen } from '../screens/screen-validation';
import { InvalidScreenWarning } from './InvalidScreenWarning';
import PasteIcon from './PasteIcon';
import { PreviewIcon } from './PreviewIcon';
import { RedoIcon } from './RedoIcon';
import { ScoringIcon } from './ScoringIcon';
import { UndoIcon } from './UndoIcon';
import { toolbarIcons, toolbarTooltips } from './toolbar-icons';

interface HeaderNavProps {
  panelState: any;
  isVisible: boolean;
  authoringContainer: React.RefObject<HTMLElement>;
  onToggleExport?: () => void;
}

// 'janus-fill-blanks'
// 'janus-navigation-button'

const staticComponents: string[] = [
  'janus_text_flow',
  'janus_image',
  'janus_video',
  //'janus_image_carousel',
  'janus_popup',
  'janus_audio',
  'janus_capi_iframe',
];
const questionComponents: string[] = [
  'janus_mcq',
  'janus_input_text',
  'janus_dropdown',
  'janus_input_number',
  'janus_slider',
  'janus_multi_line_text',
];

const ToolbarOption: React.FC<{ disabled?: boolean; component: string; onClick: () => void }> = ({
  component,
  onClick,
  disabled = false,
}) => {
  const ref = useRef<HTMLButtonElement>(null);
  const hover = useHover(ref);

  const Icon = toolbarIcons[component];
  return (
    <button
      key={component}
      onClick={onClick}
      className="component-button"
      disabled={disabled}
      ref={ref}
    >
      <OverlayTrigger
        key={component}
        placement="bottom"
        delay={{ show: 150, hide: 150 }}
        overlay={
          <Tooltip placement="top" id="button-tooltip" style={{ fontSize: '12px' }}>
            <strong>{toolbarTooltips[component]}</strong>
            {disabled && <div>Only one question component per screen is allowed</div>}
          </Tooltip>
        }
      >
        <Icon
          fill={disabled ? '#F3F5F8' : hover ? '#dce7f9' : undefined}
          stroke={disabled ? '#696974' : undefined}
        />
      </OverlayTrigger>
    </button>
  );
};

export const FlowchartHeaderNav: React.FC<HeaderNavProps> = () => {
  const projectSlug = useSelector(selectProjectSlug);
  const revisionSlug = useSelector(selectRevisionSlug);
  const availablePartComponents = useSelector(selectPartComponentTypes);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const [newPartAddOffset, setNewPartAddOffset] = useState<number>(0);
  const activities = useSelector(selectAllActivities);
  const sequence = useSelector(selectSequence);
  const currentSequenceId = useSelector(selectCurrentSequenceId);
  const dispatch = useDispatch();

  const hasRedo = useSelector(selectHasRedo);
  const hasUndo = useSelector(selectHasUndo);
  const [invalidScreens, setInvalidScreens] = React.useState<IActivity[]>([]);

  const handleUndo = () => {
    dispatch(undo(null));
  };

  const handleRedo = () => {
    dispatch(redo(null));
  };

  const paths = useSelector(selectPaths);
  const copiedPart = useSelector(selectCopiedPart);

  //const isReadOnly = useSelector(selectReadOnly);
  const currentActivity = useSelector(selectCurrentActivity);

  const questionType = getScreenQuestionType(currentActivity);
  const hasQuestion = questionType !== 'none';

  const url = `/authoring/project/${projectSlug}/preview/${revisionSlug}`;
  const windowName = `preview-${projectSlug}`;

  useEffect(() => {
    setNewPartAddOffset(0);
  }, [currentSequenceId]);

  const previewLesson = useCallback(async () => {
    await dispatch(verifyFlowchartLesson({}));
    const invalidScreens = activities.filter(
      (activity) => validateScreen(activity, activities, sequence).length > 0,
    );
    if (invalidScreens.length > 0) {
      setInvalidScreens(invalidScreens);
    } else {
      window.open(url, windowName);
    }
  }, [activities, dispatch, sequence, url, windowName]);

  const onAcceptInvalid = useCallback(() => {
    setInvalidScreens([]);
    window.open(url, windowName);
  }, [url, windowName]);

  const addPartToCurrentScreen = (newPartData: any) => {
    if (currentActivityTree) {
      const [currentActivity] = currentActivityTree.slice(-1);
      dispatch(addPart({ activityId: currentActivity.id, newPartData }));
    }
  };
  const handlePartPasteClick = () => {
    //When a part is pasted, offset the new part component by 20px from the original part
    const pasteOffset = 20;
    const newPartData = {
      id: `${copiedPart.type}-${guid()}`,
      type: copiedPart.type,
      custom: {
        ...copiedPart.custom,
        x: copiedPart.custom.x + pasteOffset,
        y: copiedPart.custom.y + pasteOffset,
      },
    };
    addPartToCurrentScreen(newPartData);
    dispatch(setCurrentSelection({ selection: newPartData.id }));

    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.COMPONENT }));
    dispatch(setCopiedPart({ copiedPart: null }));
  };

  const handleScoringOverviewClick = () => {
    dispatch(setShowScoringOverview({ show: true }));
  };

  useKeyDown(
    (ctrlKey, metaKey, shiftKey) => {
      if ((ctrlKey || metaKey) && !shiftKey) {
        handleUndo();
      }
    },
    ['KeyZ'],
    { ctrlKey: true },
  );
  useKeyDown(
    (ctrlKey, metaKey) => {
      if (ctrlKey && !metaKey) {
        handleRedo();
      }
    },
    ['KeyY'],
    { ctrlKey: true },
  );
  useKeyDown(
    (ctrlKey, metaKey, shiftKey) => {
      if ((ctrlKey || metaKey) && shiftKey) {
        handleRedo();
      }
    },
    ['KeyZ'],
    { ctrlKey: true },
  );
  useKeyDown(
    () => {
      if (copiedPart) {
        handlePartPasteClick();
      }
    },
    ['KeyV'],
    { ctrlKey: true },
    [copiedPart, currentActivityTree],
  );

  const handleAddComponent = useCallback(
    (partComponentType: string) => () => {
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
        // only ever add to the current activity, not a layer
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
        if (currentActivityTree) {
          const [currentActivity] = currentActivityTree.slice(-1);
          dispatch(addPart({ activityId: currentActivity.id, newPartData }));
        }
      }
    },
    [availablePartComponents, currentActivityTree, dispatch, newPartAddOffset],
  );

  return (
    paths && (
      <div className="component-toolbar">
        <div className="toolbar-column" style={{ flexBasis: '10%', maxWidth: 50 }}>
          <label>Undo</label>
          <button className="undo-redo-button" onClick={handleUndo} disabled={!hasUndo}>
            <UndoIcon />
          </button>
        </div>

        <div className="toolbar-column" style={{ flexBasis: '10%', maxWidth: 50 }}>
          <label>Redo</label>
          <button className="undo-redo-button" onClick={handleRedo} disabled={!hasRedo}>
            <RedoIcon />
          </button>
        </div>

        <div className="toolbar-column" style={{ flexBasis: '42%' }}>
          <label>Static Components</label>
          <div className="toolbar-buttons">
            {staticComponents.map((component) => (
              <ToolbarOption
                component={component}
                key={component}
                onClick={handleAddComponent(component)}
              />
            ))}
          </div>
        </div>

        <div className="toolbar-column" style={{ flexBasis: '42%' }}>
          <label>Question Components</label>
          <div className="toolbar-buttons">
            {questionComponents.map((component) => (
              <ToolbarOption
                disabled={hasQuestion}
                component={component}
                key={component}
                onClick={handleAddComponent(component)}
              />
            ))}
          </div>
        </div>

        <div className="toolbar-column" style={{ flexBasis: '14%' }}>
          <label>Overview</label>
          <div className="toolbar-buttons">
            <OverlayTrigger
              placement="bottom"
              delay={{ show: 150, hide: 150 }}
              overlay={
                <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  Preview Lesson
                </Tooltip>
              }
            >
              <button onClick={previewLesson} className="component-button">
                <PreviewIcon />
              </button>
            </OverlayTrigger>
            <OverlayTrigger
              placement="bottom"
              delay={{ show: 150, hide: 150 }}
              overlay={
                <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  Scoring Overview
                </Tooltip>
              }
            >
              <button onClick={handleScoringOverviewClick} className="component-button">
                <ScoringIcon />
              </button>
            </OverlayTrigger>
            {copiedPart && (
              <OverlayTrigger
                placement="bottom"
                delay={{ show: 150, hide: 150 }}
                overlay={
                  <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                    Paste Component
                  </Tooltip>
                }
              >
                <button className="component-button" onClick={handlePartPasteClick}>
                  <PasteIcon size={18} color="#222439" />
                </button>
              </OverlayTrigger>
            )}
          </div>
        </div>

        {/* <div className="btn-toolbar" role="toolbar">
          <div className="btn-group pl-3 align-items-center" role="group">
            <UndoRedoToolbar />
          </div>
          <div className="btn-group px-3 border-right align-items-center" role="group">
            <div>
              <label>Static Components</label>
              <AddComponentToolbar
                frequentlyUsed={staticComponents}
                authoringContainer={props.authoringContainer}
                showMoreComponentsMenu={false}
                showPasteComponentOption={false}
              />
            </div>

            <div>
              <label>Question Components</label>

              <AddComponentToolbar
                disabled={hasQuestion}
                frequentlyUsed={questionComponents}
                authoringContainer={props.authoringContainer}
                showMoreComponentsMenu={false}
              />
            </div>
          </div>

          <div className="btn-group pl-3 align-items-center" role="group">
            <OverlayTrigger
              placement="bottom"
              delay={{ show: 150, hide: 150 }}
              overlay={
                <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  Preview
                </Tooltip>
              }
            >
              <span>
                <button className="px-2 btn btn-link" onClick={previewLesson}>
                  <img src={`${paths.images}/icons/icon-preview.svg`}></img>
                </button>
              </span>
            </OverlayTrigger>
            <OverlayTrigger
              placement="bottom"
              delay={{ show: 150, hide: 150 }}
              overlay={
                <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  Scoring Overview
                </Tooltip>
              }
            >
              <span>
                <button className="px-2 btn btn-link" onClick={handleScoringOverviewClick}>
                  <i
                    className="fa fa-star"
                    style={{ fontSize: 32, color: '#333', verticalAlign: 'middle' }}
                  />
                </button>
              </span>
            </OverlayTrigger>

            {isReadOnly && (
              <OverlayTrigger
                placement="bottom"
                delay={{ show: 150, hide: 150 }}
                overlay={
                  <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                    Read Only
                  </Tooltip>
                }
              >
                <span>
                  <button className="px-2 btn btn-link" onClick={handleReadOnlyClick}>
                    <i
                      className="fa fa-exclamation-triangle"
                      style={{ fontSize: 40, color: 'goldenrod' }}
                    />
                  </button>
                </span>
              </OverlayTrigger>
            )}
          </div>
        </div> */}
        {invalidScreens.length > 0 && (
          <InvalidScreenWarning
            screens={invalidScreens}
            onAccept={onAcceptInvalid}
            onCancel={() => setInvalidScreens([])}
          />
        )}
      </div>
    )
  );
};

export default FlowchartHeaderNav;
