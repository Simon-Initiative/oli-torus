import React, { useCallback, useEffect, useRef, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import {
  selectCurrentPartPropertyFocus,
  setCurrentSelection,
} from 'apps/authoring/store/parts/slice';
import { useKeyDown } from 'hooks/useKeyDown';
import useHover from '../../../../../components/hooks/useHover';
import guid from '../../../../../utils/guid';
import { selectCurrentActivity } from '../../../../delivery/store/features/activities/slice';
import {
  selectCurrentActivityTree,
  selectCurrentSequenceId,
} from '../../../../delivery/store/features/groups/selectors/deck';
import {
  selectCopiedPart,
  selectPartComponentTypes,
  setCopiedPart,
  setRightPanelActiveTab,
  setShowScoringOverview,
} from '../../../store/app/slice';
import { redo } from '../../../store/history/actions/redo';
import { undo } from '../../../store/history/actions/undo';
import { selectHasRedo, selectHasUndo } from '../../../store/history/slice';
import { addPart } from '../../../store/parts/actions/addPart';
import ComponentSearchContextMenu from '../../ComponentToolbar/ComponentSearchContextMenu';
import ShowInformationModal from '../../Modal/ShowInformationModal';
import { RightPanelTabs } from '../../RightMenu/RightMenu';
import { isStaticQuestionType } from '../paths/path-options';
import { isEndScreen } from '../screens/screen-utils';
import PasteIcon from './PasteIcon';
import { RedoIcon } from './RedoIcon';
import { ScoringIcon } from './ScoringIcon';
import { TextInputIcon } from './TextInputIcon';
import { UndoIcon } from './UndoIcon';
import { toolbarIcons, toolbarTooltips } from './toolbar-icons';

const staticComponents: string[] = [
  'janus_text_flow',
  'janus_image',
  'janus_video',
  'janus_formula',
  'janus_popup',
  'janus_audio',
  'janus_capi_iframe',
  'janus_ai_trigger',
];

export const questionComponents: string[] = [
  'janus_mcq',
  'janus_input_text',
  'janus_dropdown',
  'janus_input_number',
  'janus_slider',
  'janus_multi_line_text',
  'janus_hub_spoke',
  'janus_text_slider',
];

const normalizeAdaptivePartSlug = (slug: string) => slug.replace(/_/g, '-');

export const simpleAuthorQuestionPartTypes = new Set(
  questionComponents.map(normalizeAdaptivePartSlug),
);

export const hasSimpleAuthorQuestionPart = (
  activity: { content?: { partsLayout?: any[] } } | null | undefined,
) =>
  !!activity?.content?.partsLayout?.some((part) =>
    simpleAuthorQuestionPartTypes.has(normalizeAdaptivePartSlug(part.type)),
  );

const ToolbarOption: React.FC<{
  isLessonEndScreen?: boolean;
  disabled?: boolean;
  component: string;
  onClick: () => void;
}> = ({ component, onClick, disabled = false, isLessonEndScreen = false }) => {
  const ref = useRef<HTMLButtonElement>(null);
  const hover = useHover(ref);

  const Icon = toolbarIcons[component] ?? TextInputIcon;
  const tooltip = toolbarTooltips[component] ?? component;

  if (!toolbarIcons[component]) {
    console.warn(`Missing toolbar icon mapping for flowchart component ${component}`);
  }

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
            <strong>{tooltip}</strong>
            {disabled &&
              (isLessonEndScreen ? (
                <div>Question/interaction components cannot be added to the last screen.</div>
              ) : (
                <div>Only one question component per screen is allowed</div>
              ))}
          </Tooltip>
        }
      >
        <Icon
          fill={disabled ? 'var(--color-gray-100)' : hover ? 'var(--color-gray-200)' : undefined}
          stroke={disabled ? 'var(--color-gray-500)' : undefined}
        />
      </OverlayTrigger>
    </button>
  );
};

export const FlowchartHeaderNav: React.FC = () => {
  const availablePartComponents = useSelector(selectPartComponentTypes);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentSequenceId = useSelector(selectCurrentSequenceId);
  const currentPartPropertyFocus = useSelector(selectCurrentPartPropertyFocus);
  const copiedPart = useSelector(selectCopiedPart);
  const currentActivity = useSelector(selectCurrentActivity);
  const hasRedo = useSelector(selectHasRedo);
  const hasUndo = useSelector(selectHasUndo);

  const [newPartAddOffset, setNewPartAddOffset] = useState<number>(0);
  const [showPartCopyValidationWarning, setShowPartCopyValidationWarning] =
    useState<boolean>(false);

  const dispatch = useDispatch();
  const authoringContainer = useRef<HTMLDivElement>(null);

  const isStaticTypeCopiedPart = copiedPart ? isStaticQuestionType(copiedPart) : false;
  const hasQuestion = hasSimpleAuthorQuestionPart(currentActivity);
  const isLessonEndScreen = currentActivity ? isEndScreen(currentActivity) : false;

  useEffect(() => {
    setNewPartAddOffset(0);
  }, [currentSequenceId]);

  const handleUndo = () => {
    dispatch(undo(null));
  };

  const handleRedo = () => {
    dispatch(redo(null));
  };

  const addPartToCurrentScreen = (newPartData: any) => {
    if (!currentActivityTree?.length) {
      return;
    }

    const [currentActivity] = currentActivityTree.slice(-1);
    dispatch(addPart({ activityId: currentActivity.id, newPartData }));
  };

  const handlePartPasteClick = () => {
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
      if (!copiedPart || !currentPartPropertyFocus) {
        return;
      }

      if (!isStaticTypeCopiedPart && hasQuestion) {
        setShowPartCopyValidationWarning(true);
        return;
      }

      handlePartPasteClick();
    },
    ['KeyV'],
    { ctrlKey: true },
    [copiedPart, hasQuestion, currentPartPropertyFocus],
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

      if (!PartClass) {
        return;
      }

      const defaultNewPartWidth = 100;
      const defaultNewPartHeight = 100;

      setNewPartAddOffset(newPartAddOffset + 1);

      const part = new PartClass() as any;
      const newPartData = {
        id: `${partComponentType}-${guid()}`,
        type: partComponent.delivery_element,
        custom: {
          x: 10 * newPartAddOffset,
          y: 10 * newPartAddOffset,
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
    },
    [availablePartComponents, newPartAddOffset, currentActivityTree],
  );

  return (
    <div className="component-toolbar" ref={authoringContainer}>
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
              disabled={(!isStaticTypeCopiedPart && hasQuestion) || isLessonEndScreen}
              isLessonEndScreen={isLessonEndScreen}
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
                Scoring Overview
              </Tooltip>
            }
          >
            <button onClick={handleScoringOverviewClick} className="component-button">
              <ScoringIcon />
            </button>
          </OverlayTrigger>

          <ComponentSearchContextMenu
            basicAuthoring={true}
            authoringContainer={authoringContainer}
          />

          {copiedPart && (
            <OverlayTrigger
              placement="bottom"
              delay={{ show: 150, hide: 150 }}
              overlay={
                <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  <strong>Paste Component</strong>
                  {!isStaticTypeCopiedPart && hasQuestion && (
                    <div>Only one question component per screen is allowed</div>
                  )}
                  {isLessonEndScreen && (
                    <div>Question/interaction components cannot be added to the last screen.</div>
                  )}
                </Tooltip>
              }
            >
              <button
                disabled={(!isStaticTypeCopiedPart && hasQuestion) || isLessonEndScreen}
                className="component-button"
                onClick={handlePartPasteClick}
              >
                <PasteIcon size={18} color="#222439" />
              </button>
            </OverlayTrigger>
          )}
        </div>
      </div>

      <ShowInformationModal
        show={showPartCopyValidationWarning}
        title="Paste Component"
        explanation={
          isLessonEndScreen
            ? 'Question/interaction components cannot be added to the last screen.'
            : 'Only one question component per screen is allowed'
        }
        cancelHandler={() => setShowPartCopyValidationWarning(false)}
      />
    </div>
  );
};

export default FlowchartHeaderNav;
