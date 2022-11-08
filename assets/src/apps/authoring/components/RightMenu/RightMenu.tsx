/* eslint-disable @typescript-eslint/ban-types */
import { UiSchema } from '@rjsf/core';
import { updatePart } from 'apps/authoring/store/parts/actions/updatePart';
import { JSONSchema7 } from 'json-schema';
import { debounce, isEqual } from 'lodash';
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Button, ButtonGroup, ButtonToolbar, Tab, Tabs } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { clone } from 'utils/common';
import {
  selectRightPanelActiveTab,
  setCopiedPart,
  setRightPanelActiveTab,
} from '../../../authoring/store/app/slice';
import {
  findInSequence,
  SequenceBank,
  SequenceEntry,
} from '../../../delivery/store/features/groups/actions/sequence';
import {
  selectCurrentActivityTree,
  selectCurrentSequenceId,
  selectSequence,
} from '../../../delivery/store/features/groups/selectors/deck';
import { selectCurrentGroup } from '../../../delivery/store/features/groups/slice';
import { saveActivity } from '../../store/activities/actions/saveActivity';
import { updateSequenceItem } from '../../store/groups/layouts/deck/actions/updateSequenceItemFromActivity';
import { savePage } from '../../store/page/actions/savePage';
import { selectState as selectPageState, updatePage } from '../../store/page/slice';
import { selectCurrentSelection, setCurrentSelection } from '../../store/parts/slice';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
import AccordionTemplate from '../PropertyEditor/custom/AccordionTemplate';
import CompJsonEditor from '../PropertyEditor/custom/CompJsonEditor';
import PropertyEditor from '../PropertyEditor/PropertyEditor';
import bankSchema, {
  bankUiSchema,
  transformBankModeltoSchema,
  transformBankSchematoModel,
} from '../PropertyEditor/schemas/bank';
import bankPropsSchema, {
  BankPropsUiSchema,
  transformBankPropsModeltoSchema,
  transformBankPropsSchematoModel,
} from '../PropertyEditor/schemas/bankScreen';
import lessonSchema, {
  lessonUiSchema,
  transformModelToSchema as transformLessonModel,
  transformSchemaToModel as transformLessonSchema,
} from '../PropertyEditor/schemas/lesson';
import partSchema, {
  partUiSchema,
  transformModelToSchema as transformPartModelToSchema,
  transformSchemaToModel as transformPartSchemaToModel,
} from '../PropertyEditor/schemas/part';
import screenSchema, {
  screenUiSchema,
  transformScreenModeltoSchema,
  transformScreenSchematoModel,
} from '../PropertyEditor/schemas/screen';

export enum RightPanelTabs {
  LESSON = 'lesson',
  SCREEN = 'screen',
  COMPONENT = 'component',
}

const RightMenu: React.FC<any> = () => {
  const dispatch = useDispatch();
  const selectedTab = useSelector(selectRightPanelActiveTab);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentLesson = useSelector(selectPageState);
  const currentGroup = useSelector(selectCurrentGroup);
  const currentPartSelection = useSelector(selectCurrentSelection);

  // TODO: dynamically load schema from Part Component configuration
  const [componentSchema, setComponentSchema] = useState<JSONSchema7>(partSchema);
  const [componentUiSchema, setComponentUiSchema] = useState(partUiSchema);
  const [currentComponent, setCurrentComponent] = useState(null);
  const currentSequenceId = useSelector(selectCurrentSequenceId);
  const sequence = useSelector(selectSequence);
  const currentSequence = findInSequence(sequence, currentSequenceId);

  const [currentActivity] = (currentActivityTree || []).slice(-1);

  const [scrData, setScreenData] = useState();
  const [scrSchema, setScreenSchema] = useState<JSONSchema7>();
  const [scrUiSchema, setScreenUiSchema] = useState<UiSchema>();
  const [questionBankData, setBankData] = useState<any>();
  const [questionBankSchema, setBankSchema] = useState<JSONSchema7>();
  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);

  const selectedPartDef = useMemo(
    () => findPartByIdInActivity(currentActivity, currentPartSelection),
    [currentActivity, currentPartSelection],
  );

  useEffect(() => {
    if (!currentActivity) {
      return;
    }
    /* console.log('CURRENT', { currentActivity, currentLesson }); */
    setScreenData(
      currentSequence?.custom.isBank
        ? transformBankPropsModeltoSchema(currentActivity)
        : transformScreenModeltoSchema(currentActivity),
    );
    setScreenSchema(currentSequence?.custom.isBank ? bankPropsSchema : screenSchema);
    setScreenUiSchema(currentSequence?.custom.isBank ? BankPropsUiSchema : screenUiSchema);

    setBankData(transformBankModeltoSchema(currentSequence as SequenceEntry<SequenceBank>));
    setBankSchema(bankSchema);
    const currentIds = currentActivityTree?.reduce(
      (acc, activity) => acc.concat(activity.content.partsLayout.map((p: any) => p.id)),
      [],
    );
    setExistingIds(currentIds);
  }, [currentActivity, currentSequence]);

  // should probably wrap this in state too, but it doesn't change really
  const lessonData = transformLessonModel(currentLesson);

  const handleSelectTab = (key: RightPanelTabs) => {
    // TODO: any other saving or whatever
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: key }));
  };
  const handleCopyComponent = useCallback(() => {
    if (currentActivity && currentPartSelection) {
      const partDef = findPartByIdInActivity(currentActivity, currentPartSelection);

      if (!partDef) {
        console.warn(`Part with id ${currentPartSelection} not found on this screen`);
        return;
      }
      dispatch(setCopiedPart({ copiedPart: partDef }));
    }
  }, [currentActivity, currentPartSelection]);
  const bankPropertyChangeHandler = useCallback(
    (properties: object) => {
      if (currentSequence) {
        const modelChanges = transformBankSchematoModel(properties);
        /* console.log('Bank Property Change...', { properties, modelChanges }); */
        const { bankShowCount, bankEndTarget } = modelChanges;
        if (currentSequence) {
          const cloneSequence = clone(currentSequence);
          cloneSequence.custom.bankShowCount = bankShowCount;
          cloneSequence.custom.bankEndTarget = bankEndTarget;
          dispatch(updateSequenceItem({ sequence: cloneSequence, group: currentGroup }));
          dispatch(savePage({ undoable: true }));
        }
        //debounceSaveBankSettings(currentGroup, currentSequence, bankShowCount, bankEndTarget);
      }
    },
    [currentSequence],
  );

  const debounceSaveBankSettings = useCallback(
    debounce(
      (group, currentSequence, bankShowCount, bankEndTarget) => {
        if (currentSequence) {
          const cloneSequence = clone(currentSequence);
          cloneSequence.custom.bankShowCount = bankShowCount;
          cloneSequence.custom.bankEndTarget = bankEndTarget;
          dispatch(updateSequenceItem({ sequence: cloneSequence, group: group }));
          dispatch(savePage({ undoable: true }));
        }
      },
      0,
      { maxWait: 10000, leading: false },
    ),
    [],
  );

  const screenPropertyChangeHandler = useCallback(
    (properties: object) => {
      if (currentActivity) {
        const modelChanges = currentSequence?.custom.isBank
          ? transformBankPropsSchematoModel(properties)
          : transformScreenSchematoModel(properties);
        /* console.log('Screen Property Change...', { properties, modelChanges }); */
        const { title, ...screenModelChanges } = modelChanges;
        const objectives = modelChanges.objectives || [];

        const screenChanges = {
          ...currentActivity?.content?.custom,
          ...screenModelChanges,
        };
        const cloneActivity = clone(currentActivity);
        cloneActivity.content.custom = screenChanges;

        if (objectives.length === 0) {
          // Potentially removing all objectives, clear them out
          cloneActivity.objectives = {};
        } else if (currentActivity.authoring.parts.length > 0) {
          // Adding objectives, and we have an existing part to attach them to.
          cloneActivity.objectives = {
            [currentActivity.authoring.parts[0].id]: objectives,
          };
        } else {
          // Adding objectives, but there are no parts to attach them to, saveActivity.ts will create a __default part for us
          cloneActivity.objectives = {
            __default: objectives,
          };
        }

        if (title) {
          cloneActivity.title = title;
        }
        if (JSON.stringify(cloneActivity) !== JSON.stringify(currentActivity)) {
          debounceSaveScreenSettings(cloneActivity);
        }
      }
    },
    [currentActivity],
  );

  const debounceSaveScreenSettings = useCallback(
    debounce(
      (activity) => {
        /* console.log('SAVING ACTIVITY:', { activity }); */
        dispatch(saveActivity({ activity, undoable: true }));
      },
      500,
      { maxWait: 10000, leading: false },
    ),
    [],
  );

  const debounceSavePage = useCallback(
    debounce(
      (changes) => {
        /* console.log('SAVING PAGE', { changes }); */
        // update server
        dispatch(savePage({ ...changes, undoable: true }));
        // update redux
        // TODO: check if revision slug changes?
        dispatch(updatePage(changes));
      },
      500,
      { maxWait: 10000, leading: false },
    ),
    [],
  );

  const lessonPropertyChangeHandler = useCallback(
    (properties: object) => {
      const modelChanges = transformLessonSchema(properties);

      // special consideration for legacy stylesheets
      if (modelChanges.additionalStylesheets[0] === null) {
        modelChanges.additionalStylesheets[0] = (currentLesson.additionalStylesheets || [])[0];
      }

      const lessonChanges = {
        ...currentLesson,
        ...modelChanges,
        custom: { ...currentLesson.custom, ...modelChanges.custom },
      };
      //need to remove the allowNavigation property
      //making sure the enableHistory is present before removing that.
      if (
        lessonChanges.custom.enableHistory !== undefined &&
        lessonChanges.custom.allowNavigation !== undefined
      ) {
        delete lessonChanges.custom.allowNavigation;
      }
      /* console.log('LESSON PROP CHANGED', { modelChanges, lessonChanges, properties }); */

      // need to put a healthy debounce in here, this fires every keystroke
      // save the page
      if (JSON.stringify(lessonChanges) !== JSON.stringify(currentLesson)) {
        debounceSavePage(lessonChanges);
      }
    },
    [currentLesson],
  );

  const debouncePartPropertyChanges = useCallback(
    debounce(
      (properties, partInstance, origActivity, origId) => {
        let modelChanges = properties;

        // do not allow saving of bad ID
        if (!modelChanges.id || !modelChanges.id.trim()) {
          modelChanges.id = origId;
        }

        modelChanges = transformPartSchemaToModel(modelChanges);
        if (partInstance && partInstance.transformSchemaToModel) {
          modelChanges.custom = {
            ...modelChanges.custom,
            ...partInstance.transformSchemaToModel(modelChanges.custom),
          };
        }

        /* console.log('COMPONENT PROP CHANGED', { properties, modelChanges }); */
        dispatch(
          updatePart({ activityId: origActivity.id, partId: origId, changes: modelChanges }),
        );

        // in case the id changes, update the selection
        dispatch(setCurrentSelection({ selection: modelChanges.id }));
      },
      500,
      { maxWait: 10000, leading: false },
    ),
    [],
  );

  const [currentComponentData, setCurrentComponentData] = useState<any>();
  const [currentPartInstance, setCurrentPartInstance] = useState(null);
  const [existingIds, setExistingIds] = useState<string[]>([]);
  useEffect(() => {
    if (!currentPartSelection || !currentActivityTree) {
      return;
    }
    let partDef;
    for (let i = 0; i < currentActivityTree.length; i++) {
      const activity = currentActivityTree[i];
      partDef = activity.content?.partsLayout.find((part: any) => part.id === currentPartSelection);
      if (partDef) {
        break;
      }
    }
    /* console.log('part selected', { partDef }); */
    if (partDef) {
      // part component should be registered by type as a custom element
      const PartClass = customElements.get(partDef.type);
      if (PartClass) {
        const instance = new PartClass() as any;

        setCurrentPartInstance(instance);

        let data = clone(partDef);
        if (instance.transformModelToSchema) {
          // because the part schema below only knows about the "custom" block
          data.custom = { ...data.custom, ...instance.transformModelToSchema(partDef.custom) };
        }
        data = transformPartModelToSchema(data);
        setCurrentComponentData(data);

        // schema
        if (instance.getSchema) {
          const customPartSchema = instance.getSchema();
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
          setComponentSchema(newSchema);
        }

        // ui schema
        if (instance.getUiSchema) {
          const customPartUiSchema = instance.getUiSchema();
          const newUiSchema = {
            ...partUiSchema,
            custom: {
              'ui:ObjectFieldTemplate': AccordionTemplate,
              'ui:title': 'Custom',
              ...customPartUiSchema,
            },
          };
          setComponentUiSchema(newUiSchema);
        }
      }
      setCurrentComponent(partDef);
    }
    return () => {
      setComponentSchema(partSchema);
      setComponentUiSchema(partUiSchema);
      setCurrentComponent(null);
      setCurrentComponentData(null);
      setCurrentPartInstance(null);
    };
  }, [currentPartSelection, currentActivityTree]);

  const componentPropertyChangeHandler = useCallback(
    (properties: object) => {
      debouncePartPropertyChanges(
        properties,
        currentPartInstance,
        currentActivity,
        currentPartSelection,
      );
    },
    [currentActivity, currentPartInstance, currentPartSelection, debouncePartPropertyChanges],
  );

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
  const DeleteComponentHandler = () => {
    handleDeleteComponent();
    setShowConfirmDelete(false);
  };
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
  }, [currentPartSelection, currentActivity]);

  return (
    <Tabs
      className="aa-panel-section-title-bar aa-panel-tabs"
      activeKey={selectedTab}
      onSelect={handleSelectTab}
    >
      <Tab eventKey={RightPanelTabs.LESSON} title="Lesson">
        <div className="lesson-tab overflow-hidden">
          <PropertyEditor
            schema={lessonSchema as JSONSchema7}
            uiSchema={lessonUiSchema}
            value={lessonData}
            triggerOnChange={['CustomLogic']}
            onChangeHandler={lessonPropertyChangeHandler}
          />
        </div>
      </Tab>
      <Tab eventKey={RightPanelTabs.SCREEN} title="Screen">
        {currentActivity && currentSequence && currentSequence?.custom.isBank ? (
          <div className="bank-tab p-3">
            <PropertyEditor
              key={currentActivity.id}
              schema={questionBankSchema as JSONSchema7}
              uiSchema={bankUiSchema}
              value={questionBankData}
              onChangeHandler={bankPropertyChangeHandler}
            />
          </div>
        ) : null}
        <div className="screen-tab p-3 overflow-hidden">
          {currentActivity && scrData ? (
            <PropertyEditor
              key={currentActivity.id}
              schema={scrSchema as JSONSchema7}
              uiSchema={scrUiSchema as UiSchema}
              value={scrData}
              onChangeHandler={screenPropertyChangeHandler}
            />
          ) : null}
        </div>
      </Tab>
      <Tab eventKey={RightPanelTabs.COMPONENT} title="Component" disabled={!currentComponent}>
        {currentComponent && currentComponentData && (
          <div className="component-tab p-3 overflow-hidden">
            <ButtonToolbar aria-label="Component Tools">
              <ButtonGroup className="me-2" aria-label="First group">
                <Button>
                  <i className="fas fa-wrench mr-2" />
                </Button>
                <Button>
                  <i className="fas fa-cog mr-2" />
                </Button>
                <Button>
                  <i className="fas fa-copy mr-2" onClick={() => handleCopyComponent()} />
                </Button>
                {selectedPartDef && (
                  <CompJsonEditor
                    onChange={handleEditComponentJson}
                    jsonValue={selectedPartDef}
                    existingPartIds={existingIds}
                  />
                )}
                <Button variant="danger" onClick={() => setShowConfirmDelete(true)}>
                  <i className="fas fa-trash mr-2" />
                </Button>
                <ConfirmDelete
                  show={showConfirmDelete}
                  elementType="Component"
                  elementName={currentComponentData?.id}
                  deleteHandler={DeleteComponentHandler}
                  cancelHandler={() => {
                    setShowConfirmDelete(false);
                  }}
                />
              </ButtonGroup>
            </ButtonToolbar>
            <PropertyEditor
              key={currentComponentData.id}
              schema={componentSchema}
              uiSchema={componentUiSchema}
              value={currentComponentData}
              onChangeHandler={componentPropertyChangeHandler}
            />
          </div>
        )}
      </Tab>
    </Tabs>
  );
};

const findPartByIdInActivity = (currentActivity: any, targetPartId: string) => {
  if (!currentActivity || !targetPartId) return null;
  return currentActivity.content?.partsLayout.find((part: any) => part.id === targetPartId);
};

export default RightMenu;
