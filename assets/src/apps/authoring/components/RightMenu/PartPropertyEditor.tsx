import React, { useCallback, useMemo, useRef } from 'react';
import { Alert, Button, ButtonGroup, ButtonToolbar } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { JSONSchema7 } from 'json-schema';
import { isEqual } from 'lodash';
import { updatePart } from 'apps/authoring/store/parts/actions/updatePart';
import { useToggle } from '../../../../components/hooks/useToggle';
import {
  isDefaultNumericCorrectAnswer,
  requiresNumericCorrectAnswer,
} from '../../../../components/parts/numericCorrectnessDefaults';
import { PartAuthoringMode } from '../../../../components/parts/partsApi';
import { clone } from '../../../../utils/common';
import { IActivity } from '../../../delivery/store/features/activities/slice';
import { saveActivity } from '../../store/activities/actions/saveActivity';
import {
  selectAllowTriggers,
  selectAppMode,
  selectReadOnly,
  setCopiedPart,
  setCopiedPartActivityId,
  setRightPanelActiveTab,
} from '../../store/app/slice';
import { selectState as selectPageState } from '../../store/page/slice';
import { setCurrentPartPropertyFocus, setCurrentSelection } from '../../store/parts/slice';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
import PropertyEditor from '../PropertyEditor/PropertyEditor';
import AccordionTemplate from '../PropertyEditor/custom/AccordionTemplate';
import CompJsonEditor from '../PropertyEditor/custom/CompJsonEditor';
import partSchema, {
  isAdaptiveScorablePartType,
  partUiSchema,
  removeScoringFromSchema,
  removeScoringFromUiSchema,
  responsivePartSchema,
  responsivePartUiSchema,
  simplifiedPartSchema,
  simplifiedPartUiSchema,
  transformModelToSchema as transformPartModelToSchema,
  transformSchemaToModel as transformPartSchemaToModel,
} from '../PropertyEditor/schemas/part';
import { RightPanelTabs } from './RightPanelTabs';

interface Props {
  currentActivity: IActivity;
  currentActivityTree: IActivity[];
  currentPartSelection: string;
  existingIds: string[];
  readOnly?: boolean;
}

const findPartByIdInActivity = (currentActivity: any, targetPartId: string) => {
  if (!currentActivity || !targetPartId) return null;
  return currentActivity.content?.partsLayout.find((part: any) => part.id === targetPartId);
};

const getCurrentPartInstance = (type: string) => {
  const PartClass = customElements.get(type);
  if (PartClass) {
    return new PartClass() as any;
  }
  return null;
};

const getPartDef = (currentActivityTree: any, currentPartSelection: any) => {
  let partDef;
  for (let i = 0; i < currentActivityTree.length; i++) {
    const activity = currentActivityTree[i];
    partDef = activity.content?.partsLayout.find((part: any) => part.id === currentPartSelection);
    if (partDef) {
      break;
    }
  }
  return partDef;
};

const getComponentData = (instance: any, partDef: any) => {
  if (!instance || !partDef) return null;
  const data = clone(partDef);
  if (instance.transformModelToSchema) {
    // because the part schema below only knows about the "custom" block
    data.custom = { ...data.custom, ...instance.transformModelToSchema(partDef.custom) };
  }
  return transformPartModelToSchema(data);
};

const getComponentSchema = (
  instance: any,
  partEditMode: PartAuthoringMode,
  responsiveLayout: boolean,
  allowTriggers: boolean,
): JSONSchema7 => {
  return partEditMode === 'simple'
    ? getSimplifiedComponentSchema(instance, allowTriggers)
    : getExpertComponentSchema(instance, responsiveLayout, allowTriggers);
};

// The "simple" ui with only the common properties sorted in a logical order
const getSimplifiedComponentSchema = (instance: any, allowTriggers: boolean): JSONSchema7 => {
  const tagName = instance ? String(instance.tagName).toLowerCase() : '';
  const showScoring = isAdaptiveScorablePartType(tagName);
  const baseSchema = showScoring
    ? simplifiedPartSchema
    : removeScoringFromSchema(simplifiedPartSchema);

  if (instance && instance.getSchema) {
    const customPartSchema = instance.getSchema('simple', { allowAiTriggers: allowTriggers });
    const newSchema: any = {
      ...baseSchema,
      properties: {
        custom: { type: 'object', properties: { ...customPartSchema } },
        ...baseSchema.properties,
      },
    };
    if (customPartSchema.definitions) {
      newSchema.definitions = customPartSchema.definitions;
      delete newSchema.properties.custom.properties.definitions;
    }

    if (customPartSchema.allOf) {
      // This is getting into hacky territory, a better solution would be if each component returned the full schema instead of just the
      // properties part of the schema, then each component could actually control it's whole schema.
      newSchema.properties.custom.allOf = customPartSchema.allOf;
      delete newSchema.properties.custom.properties.allOf;
    }
    return newSchema;
  }

  return baseSchema; // default schema for components that don't specify.
};

const getExpertComponentSchema = (
  instance: any,
  responsiveLayout: boolean,
  allowTriggers: boolean,
): JSONSchema7 => {
  const tagName = instance ? String(instance.tagName).toLowerCase() : '';
  const baseSchema = responsiveLayout ? responsivePartSchema : partSchema;
  const showScoring = isAdaptiveScorablePartType(tagName);
  const filteredBaseSchema = showScoring ? baseSchema : removeScoringFromSchema(baseSchema);

  if (instance && instance.getSchema) {
    const customPartSchema = instance.getSchema('expert', { allowAiTriggers: allowTriggers });
    const simplePartSchema = showScoring
      ? instance.getSchema('simple', { allowAiTriggers: allowTriggers })
      : null;

    const mergedCustomPartSchema = mergeAdaptiveExpertSchema(customPartSchema, simplePartSchema);
    const mergedCustomPartProperties = schemaPropertyMap(mergedCustomPartSchema);
    const newSchema: any = {
      ...filteredBaseSchema,
      properties: {
        ...filteredBaseSchema.properties,
        custom: { type: 'object', properties: { ...mergedCustomPartProperties } },
      },
    };
    if (mergedCustomPartSchema.definitions) {
      newSchema.definitions = mergedCustomPartSchema.definitions;
    }

    if (mergedCustomPartSchema.allOf) {
      newSchema.properties.custom.allOf = mergedCustomPartSchema.allOf;
    }
    return newSchema;
  }

  return filteredBaseSchema; // default schema for components that don't specify.
};

const getComponentUISchema = (
  instance: any,
  partEditMode: PartAuthoringMode,
  responsiveLayout: boolean,
) => {
  return partEditMode === 'simple'
    ? getSimplifiedComponentUISchema(instance)
    : getExpertComponentUISchema(instance, responsiveLayout);
};

const simplifiedLabels: Record<string, string> = {
  'janus-text-flow': 'Text Flow',
  'janus-image': 'Image',
  'janus-ai-trigger': 'AI Activation Point',
  'janus-video': 'Video',
  'janus-popup': 'Popup Icon',
  'janus-audio': 'Audio',
  'janus-capi-iframe': 'iFrame',
  'janus-mcq': 'Multiple Choice Question',
  'janus-input-text': 'Text Input',
  'janus-input-number': 'Number Input',
  'janus-dropdown': 'Dropdown',
  'janus-slider': 'Slider',
  'janus-multi-line-text': 'Multi line text input',
  'janus-hub-spoke': 'Hub and Spoke',
};

const simplifiedDescriptionLabels: Record<string, string> = {
  'janus-hub-spoke':
    'Hub and Spoke is a path layout of a main hub and one-screen paths (spokes) from the hub',
};

const getSimplifiedComponentUISchema = (instance: any) => {
  // ui schema
  const tagName = instance ? String(instance.tagName).toLowerCase() : '';
  const title = simplifiedLabels[tagName] || 'Component Options';
  const componentDescription = simplifiedDescriptionLabels[tagName] || '';
  const baseUiSchema = isAdaptiveScorablePartType(tagName)
    ? simplifiedPartUiSchema
    : removeScoringFromUiSchema(simplifiedPartUiSchema);
  if (instance && instance.getUiSchema) {
    const customPartUiSchema = instance.getUiSchema('simple');
    const newUiSchema = {
      ...baseUiSchema,
      custom: {
        'ui:title': title,
        'ui:description': componentDescription,
        ...customPartUiSchema,
      },
    };
    return newUiSchema;
  }
  return baseUiSchema; // default ui schema for components that don't specify.
};

const getExpertComponentUISchema = (instance: any, responsiveLayout: boolean) => {
  // ui schema
  const tagName = instance ? String(instance.tagName).toLowerCase() : '';
  const componentUiSchema = responsiveLayout ? responsivePartUiSchema : partUiSchema;
  const baseUiSchema = isAdaptiveScorablePartType(tagName)
    ? componentUiSchema
    : removeScoringFromUiSchema(componentUiSchema);
  if (instance && instance.getUiSchema) {
    const customPartUiSchema = instance.getUiSchema('expert');
    const simplePartUiSchema =
      isAdaptiveScorablePartType(tagName) && instance.getUiSchema
        ? instance.getUiSchema('simple')
        : null;

    const mergedCustomPartUiSchema = mergeAdaptiveExpertUiSchema(
      customPartUiSchema,
      simplePartUiSchema,
    );

    const newUiSchema = {
      ...baseUiSchema,
      custom: {
        'ui:ObjectFieldTemplate': AccordionTemplate,
        'ui:title': 'Custom',
        ...mergedCustomPartUiSchema,
      },
    };
    return newUiSchema;
  }
  return baseUiSchema; // default ui schema  for components that don't specify.
};

const mergeAdaptiveExpertSchema = (expertSchema: any, simpleSchema: any) => {
  if (!simpleSchema) return expertSchema;

  const expertProperties = schemaPropertyMap(expertSchema);
  const simpleProperties = schemaPropertyMap(simpleSchema);

  const mergedProperties = { ...simpleProperties, ...expertProperties };

  const merged: any = { ...mergedProperties };

  const mergedDefinitions = {
    ...(simpleSchema?.definitions || {}),
    ...(expertSchema?.definitions || {}),
  };

  if (Object.keys(mergedDefinitions).length > 0) {
    merged.definitions = mergedDefinitions;
  }

  const allOf = [...(simpleSchema?.allOf || []), ...(expertSchema?.allOf || [])];
  if (allOf.length > 0) {
    merged.allOf = allOf;
  }

  return merged;
};

const mergeAdaptiveExpertUiSchema = (expertUiSchema: any, simpleUiSchema: any) => {
  if (!simpleUiSchema) return expertUiSchema;
  const merged = {
    ...simpleUiSchema,
    ...expertUiSchema,
  };

  delete merged['ui:order'];

  return merged;
};

const schemaPropertyMap = (schema: any) => {
  if (!schema) return {};

  return Object.entries(schema).reduce((acc, [key, value]) => {
    if (key === 'definitions' || key === 'allOf') return acc;
    acc[key] = value;
    return acc;
  }, {} as Record<string, any>);
};

export const PartPropertyEditor: React.FC<Props> = ({
  currentActivity,
  currentActivityTree,
  currentPartSelection,
  existingIds,
  readOnly = false,
}) => {
  const editorInstanceId = useRef(`part_${Math.random().toString(36).slice(2, 10)}`);
  const dispatch = useDispatch();
  const currentLesson = useSelector(selectPageState);
  const responsiveLayout = currentLesson?.custom?.responsiveLayout || false;
  const appMode = useSelector(selectAppMode);
  const allowTriggers = useSelector(selectAllowTriggers);
  const isReadOnly = useSelector(selectReadOnly);
  const partEditMode: PartAuthoringMode = appMode === 'expert' ? 'expert' : 'simple';

  const [shouldShowConfirmDelete, , showConfirmDelete, hideConfirmDelete] = useToggle(false);

  const partDef = useMemo(
    () => getPartDef(currentActivityTree, currentPartSelection),
    [currentActivityTree, currentPartSelection],
  );

  const currentPartInstance = useMemo(() => getCurrentPartInstance(partDef?.type), [partDef?.type]);

  const selectedPartDef = useMemo(
    () => findPartByIdInActivity(currentActivity, currentPartSelection),
    [currentActivity, currentPartSelection],
  );

  const numericCorrectAnswerNeedsReview = useMemo(() => {
    if (!selectedPartDef || !requiresNumericCorrectAnswer(selectedPartDef.type)) {
      return false;
    }

    return isDefaultNumericCorrectAnswer(selectedPartDef.custom?.answer, selectedPartDef.custom);
  }, [selectedPartDef]);

  const currentComponentData = useMemo(
    () => getComponentData(currentPartInstance, partDef),
    [currentPartInstance, partDef],
  );

  const componentSchema = useMemo(
    () => getComponentSchema(currentPartInstance, partEditMode, responsiveLayout, allowTriggers),
    [allowTriggers, currentPartInstance, partEditMode, responsiveLayout],
  );

  const componentUiSchema = useMemo(
    () => getComponentUISchema(currentPartInstance, partEditMode, responsiveLayout),
    [currentPartInstance, partEditMode, responsiveLayout],
  );

  const handleDeleteComponent = useCallback(() => {
    if (readOnly || isReadOnly) {
      return;
    }
    // only allow delete of "owned" parts
    // TODO: disable/hide button if that is not owned
    if (!currentActivity || !currentPartSelection) {
      return;
    }
    const partDef = currentActivity.content?.partsLayout.find(
      (part: any) => part.id === currentPartSelection,
    );
    if (!partDef) {
      console.warn(`Part with id ${currentPartSelection} not found on this screen`);
      return;
    }
    const cloneActivity = clone(currentActivity);
    cloneActivity.authoring.parts = cloneActivity.authoring.parts.filter(
      (part: any) => part.id !== currentPartSelection,
    );
    cloneActivity.content.partsLayout = cloneActivity.content.partsLayout.filter(
      (part: any) => part.id !== currentPartSelection,
    );
    dispatch(saveActivity({ activity: cloneActivity, undoable: true }));
    dispatch(setCurrentSelection({ selection: '' }));
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
  }, [currentActivity, currentPartSelection, dispatch, isReadOnly, readOnly]);

  const DeleteComponentHandler = () => {
    handleDeleteComponent();
    showConfirmDelete();
  };

  const handleCopyComponent = useCallback(() => {
    if (readOnly || isReadOnly) {
      return;
    }
    if (currentActivity && currentPartSelection) {
      const partDef = findPartByIdInActivity(currentActivity, currentPartSelection);

      if (!partDef) {
        console.warn(`Part with id ${currentPartSelection} not found on this screen`);
        return;
      }
      dispatch(setCopiedPart({ copiedPart: partDef }));
      dispatch(setCopiedPartActivityId({ copiedPart: currentActivity?.id }));
    }
  }, [currentActivity, currentPartSelection, dispatch, isReadOnly, readOnly]);

  const handleEditComponentJson = (newJson: any) => {
    if (readOnly || isReadOnly) {
      return;
    }
    const cloneActivity = clone(currentActivity);
    const ogPart = cloneActivity.content?.partsLayout.find(
      (part: any) => part.id === currentPartSelection,
    );
    if (!ogPart) {
      console.warn(
        'couldnt find part in current activity, most like lives on a layer; you need to update they layer copy directly',
      );
      return;
    }
    if (newJson.id !== '' && newJson.id !== ogPart.id) {
      ogPart.id = newJson.id;
      // in case the id changes, update the selection
      dispatch(setCurrentSelection({ selection: newJson.id }));
    }
    ogPart.custom = newJson.custom;
    if (!isEqual(cloneActivity, currentActivity)) {
      dispatch(saveActivity({ activity: cloneActivity, undoable: true }));
    }
  };

  const componentPropertyChangeHandler = useCallback(
    (properties: any) => {
      if (readOnly || isReadOnly) {
        return;
      }
      let modelChanges = properties;

      // do not allow saving of bad ID
      if (!modelChanges.id || !modelChanges.id.trim()) {
        modelChanges.id = currentPartSelection;
      }

      // We can use the same transformation functions for expert & simplified because the RJSF library passes
      // back any unknown properties unchanged.
      modelChanges = transformPartSchemaToModel(modelChanges);

      if (currentPartInstance && currentPartInstance.transformSchemaToModel) {
        modelChanges.custom = {
          ...modelChanges.custom,
          ...currentPartInstance.transformSchemaToModel(modelChanges.custom),
        };
      }

      /* console.log('COMPONENT PROP CHANGED', { properties, modelChanges }); */
      dispatch(
        updatePart({
          activityId: String(currentActivity.id),
          partId: currentPartSelection,
          changes: modelChanges,
          mergeChanges: false,
        }),
      );

      // in case the id changes, update the selection
      dispatch(setCurrentSelection({ selection: modelChanges.id }));
    },
    [currentActivity.id, currentPartInstance, currentPartSelection, dispatch, isReadOnly, readOnly],
  );

  const componentPropertyFocusHandler = useCallback(
    (partPropertyElementFocus: boolean) => {
      dispatch(setCurrentPartPropertyFocus({ focus: partPropertyElementFocus }));
    },
    [currentActivity.id, currentPartInstance, currentPartSelection, dispatch],
  );

  if (!partDef) return null;

  const selectPartType = selectedPartDef?.type || '';

  return (
    <div
      className={`component-tab p-3 overflow-hidden part-property-editor ${selectPartType}-part-property`}
    >
      {selectPartType === 'janus-fill-blanks' && (
        <Alert variant="info" className="part-documentation">
          <a
            href="https://etx-tech.notion.site/FITB-Component-New-20862d4b114580948615d0ccd2706450"
            target="_blank"
            rel="noreferrer"
          >
            <i className="fa-solid fa-circle-info"></i> How to Use This Component{' '}
          </a>
        </Alert>
      )}
      {numericCorrectAnswerNeedsReview && (
        <Alert variant="warning" className="part-documentation">
          This numeric adaptive input was added with a default correct answer. Review the scoring
          settings before publishing if the default value is not the intended answer.
        </Alert>
      )}
      {selectedPartDef && partEditMode === 'expert' && (
        <ButtonToolbar aria-label="Component Tools">
          <ButtonGroup className="me-2" aria-label="First group">
            <div className="input-group-prepend">
              <div className="input-group-text" id="btnGroupAddon">
                <i className="fas fa-wrench mr-2" />
              </div>
            </div>
            <Button disabled={readOnly || isReadOnly}>
              <i className="fas fa-copy mr-2" onClick={() => handleCopyComponent()} />
            </Button>

            <CompJsonEditor
              disabled={readOnly || isReadOnly}
              onChange={handleEditComponentJson}
              jsonValue={selectedPartDef}
              existingPartIds={existingIds}
              onfocusHandler={componentPropertyFocusHandler}
            />

            <Button variant="danger" disabled={readOnly || isReadOnly} onClick={showConfirmDelete}>
              <i className="fas fa-trash mr-2" />
            </Button>

            <ConfirmDelete
              show={shouldShowConfirmDelete}
              elementType="Component"
              elementName={currentComponentData?.id}
              deleteHandler={DeleteComponentHandler}
              cancelHandler={hideConfirmDelete}
            />
          </ButtonGroup>
        </ButtonToolbar>
      )}
      <PropertyEditor
        key={currentComponentData.id}
        idPrefix={`component_${editorInstanceId.current}_${currentComponentData.id}`}
        schema={componentSchema}
        uiSchema={componentUiSchema}
        value={currentComponentData}
        disabled={readOnly || isReadOnly}
        onChangeHandler={componentPropertyChangeHandler}
        triggerOnChange={true}
        onfocusHandler={componentPropertyFocusHandler}
        isExpertMode={appMode === 'expert'}
      />
    </div>
  );
};
