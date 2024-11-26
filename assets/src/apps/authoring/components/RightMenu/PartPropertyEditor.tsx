import React, { useCallback, useMemo } from 'react';
import { Button, ButtonGroup, ButtonToolbar } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { JSONSchema7 } from 'json-schema';
import { isEqual } from 'lodash';
import { updatePart } from 'apps/authoring/store/parts/actions/updatePart';
import { useToggle } from '../../../../components/hooks/useToggle';
import { PartAuthoringMode } from '../../../../components/parts/partsApi';
import { clone } from '../../../../utils/common';
import { IActivity } from '../../../delivery/store/features/activities/slice';
import { saveActivity } from '../../store/activities/actions/saveActivity';
import {
  selectAppMode,
  setCopiedPart,
  setCopiedPartActivityId,
  setRightPanelActiveTab,
} from '../../store/app/slice';
import { setCurrentPartPropertyFocus, setCurrentSelection } from '../../store/parts/slice';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
import PropertyEditor from '../PropertyEditor/PropertyEditor';
import AccordionTemplate from '../PropertyEditor/custom/AccordionTemplate';
import CompJsonEditor from '../PropertyEditor/custom/CompJsonEditor';
import partSchema, {
  partUiSchema,
  simplifiedPartSchema,
  simplifiedPartUiSchema,
  transformModelToSchema as transformPartModelToSchema,
  transformSchemaToModel as transformPartSchemaToModel,
} from '../PropertyEditor/schemas/part';
import { RightPanelTabs } from './RightMenu';

interface Props {
  currentActivity: IActivity;
  currentActivityTree: IActivity[];
  currentPartSelection: string;
  existingIds: string[];
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

const getComponentSchema = (instance: any, partEditMode: PartAuthoringMode): JSONSchema7 => {
  return partEditMode === 'simple'
    ? getSimplifiedComponentSchema(instance)
    : getExpertComponentSchema(instance);
};

// The "simple" ui with only the common properties sorted in a logical order
const getSimplifiedComponentSchema = (instance: any): JSONSchema7 => {
  if (instance && instance.getSchema) {
    const customPartSchema = instance.getSchema('simple');
    const newSchema: any = {
      ...simplifiedPartSchema,
      properties: {
        custom: { type: 'object', properties: { ...customPartSchema } },
        ...simplifiedPartSchema.properties,
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

  return simplifiedPartSchema; // default schema for components that don't specify.
};

const getExpertComponentSchema = (instance: any): JSONSchema7 => {
  if (instance && instance.getSchema) {
    const customPartSchema = instance.getSchema('expert');
    const newSchema: any = {
      ...partSchema,
      properties: {
        ...partSchema.properties,
        custom: { type: 'object', properties: { ...customPartSchema } },
      },
    };
    if (customPartSchema.definitions) {
      newSchema.definitions = customPartSchema.definitions;
      delete newSchema.properties.custom.properties.definitions;
    }
    return newSchema;
  }

  return partSchema; // default schema for components that don't specify.
};

const getComponentUISchema = (instance: any, partEditMode: PartAuthoringMode) => {
  return partEditMode === 'simple'
    ? getSimplifiedComponentUISchema(instance)
    : getExpertComponentUISchema(instance);
};

const simplifiedLabels: Record<string, string> = {
  'janus-text-flow': 'Text Flow',
  'janus-image': 'Image',
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
};

const getSimplifiedComponentUISchema = (instance: any) => {
  // ui schema
  const tagName = instance ? String(instance.tagName).toLowerCase() : '';
  const title = simplifiedLabels[tagName] || 'Component Options';

  if (instance && instance.getUiSchema) {
    const customPartUiSchema = instance.getUiSchema('simple');
    const newUiSchema = {
      ...simplifiedPartUiSchema,
      custom: {
        'ui:title': title,
        ...customPartUiSchema,
      },
    };
    return newUiSchema;
  }
  return simplifiedPartUiSchema; // default ui schema for components that don't specify.
};

const getExpertComponentUISchema = (instance: any) => {
  // ui schema
  if (instance && instance.getUiSchema) {
    const customPartUiSchema = instance.getUiSchema('expert');
    const newUiSchema = {
      ...partUiSchema,
      custom: {
        'ui:ObjectFieldTemplate': AccordionTemplate,
        'ui:title': 'Custom',
        ...customPartUiSchema,
      },
    };
    return newUiSchema;
  }
  return partUiSchema; // default ui schema  for components that don't specify.
};

export const PartPropertyEditor: React.FC<Props> = ({
  currentActivity,
  currentActivityTree,
  currentPartSelection,
  existingIds,
}) => {
  const dispatch = useDispatch();

  const appMode = useSelector(selectAppMode);
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

  const currentComponentData = useMemo(
    () => getComponentData(currentPartInstance, partDef),
    [currentPartInstance, partDef],
  );

  const componentSchema = useMemo(
    () => getComponentSchema(currentPartInstance, partEditMode),
    [currentPartInstance, partEditMode],
  );

  const componentUiSchema = useMemo(
    () => getComponentUISchema(currentPartInstance, partEditMode),
    [currentPartInstance, partEditMode],
  );

  const handleDeleteComponent = useCallback(() => {
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
  }, [currentActivity, currentPartSelection, dispatch]);

  const DeleteComponentHandler = () => {
    handleDeleteComponent();
    showConfirmDelete();
  };

  const handleCopyComponent = useCallback(() => {
    if (currentActivity && currentPartSelection) {
      const partDef = findPartByIdInActivity(currentActivity, currentPartSelection);

      if (!partDef) {
        console.warn(`Part with id ${currentPartSelection} not found on this screen`);
        return;
      }
      dispatch(setCopiedPart({ copiedPart: partDef }));
      dispatch(setCopiedPartActivityId({ copiedPart: currentActivity?.id }));
    }
  }, [currentActivity, currentPartSelection, dispatch]);

  const handleEditComponentJson = (newJson: any) => {
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
    [currentActivity.id, currentPartInstance, currentPartSelection, dispatch],
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
    <div className={`component-tab p-3 overflow-hidden part-property-editor ${selectPartType}`}>
      {selectedPartDef && partEditMode === 'expert' && (
        <ButtonToolbar aria-label="Component Tools">
          <ButtonGroup className="me-2" aria-label="First group">
            <div className="input-group-prepend">
              <div className="input-group-text" id="btnGroupAddon">
                <i className="fas fa-wrench mr-2" />
              </div>
            </div>
            <Button>
              <i className="fas fa-copy mr-2" onClick={() => handleCopyComponent()} />
            </Button>

            <CompJsonEditor
              onChange={handleEditComponentJson}
              jsonValue={selectedPartDef}
              existingPartIds={existingIds}
            />

            <Button variant="danger" onClick={showConfirmDelete}>
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
        schema={componentSchema}
        uiSchema={componentUiSchema}
        value={currentComponentData}
        onChangeHandler={componentPropertyChangeHandler}
        triggerOnChange={true}
        onfocusHandler={componentPropertyFocusHandler}
      />
    </div>
  );
};
