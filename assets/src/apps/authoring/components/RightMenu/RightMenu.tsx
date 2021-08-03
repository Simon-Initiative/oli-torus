import { JSONSchema7 } from 'json-schema';
import { debounce } from 'lodash';
import React, { useCallback, useEffect, useState } from 'react';
import { Tab, Tabs } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { clone } from 'utils/common';
import {
  selectRightPanelActiveTab,
  setRightPanelActiveTab,
} from '../../../authoring/store/app/slice';
import { upsertActivity } from '../../../delivery/store/features/activities/slice';
import { selectCurrentActivityTree } from '../../../delivery/store/features/groups/selectors/deck';
import { selectCurrentGroup } from '../../../delivery/store/features/groups/slice';
import { saveActivity } from '../../store/activities/actions/saveActivity';
import { updateSequenceItemFromActivity } from '../../store/groups/layouts/deck/actions/updateSequenceItemFromActivity';
import { savePage } from '../../store/page/actions/savePage';
import { selectState as selectPageState, updatePage } from '../../store/page/slice';
import { selectCurrentSelection } from '../../store/parts/slice';
import AccordionTemplate from '../PropertyEditor/custom/AccordionTemplate';
import ColorPickerWidget from '../PropertyEditor/custom/ColorPickerWidget';
import CustomFieldTemplate from '../PropertyEditor/custom/CustomFieldTemplate';
import PropertyEditor from '../PropertyEditor/PropertyEditor';
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
  const [componentSchema, setComponentSchema]: any = useState<any>(partSchema);
  const [componentUiSchema, setComponentUiSchema]: any = useState<any>(partUiSchema);
  const [currentComponent, setCurrentComponent] = useState<any>(null);

  const [currentActivity] = (currentActivityTree || []).slice(-1);

  const [screenData, setScreenData] = useState();
  useEffect(() => {
    if (!currentActivity) {
      return;
    }
    console.log('CURRENT', { currentActivity, currentLesson });
    setScreenData(transformScreenModeltoSchema(currentActivity));
  }, [currentActivity]);

  // should probably wrap this in state too, but it doesn't change really
  const lessonData = transformLessonModel(currentLesson);

  const handleSelectTab = (key: RightPanelTabs) => {
    // TODO: any other saving or whatever
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: key }));
  };

  const screenPropertyChangeHandler = useCallback(
    (properties: any) => {
      if (currentActivity) {
        const modelChanges = transformScreenSchematoModel(properties);
        console.log('Screen Property Change...', { properties, modelChanges });
        const title = modelChanges.title;
        delete modelChanges.title;
        const screenChanges = {
          ...currentActivity?.content?.custom,
          ...modelChanges,
        };
        const cloneActivity = clone(currentActivity);
        cloneActivity.content.custom = screenChanges;
        if (title) {
          cloneActivity.title = title;
        }
        debounceSaveScreenSettings(cloneActivity, currentActivity, currentGroup);
      }
    },
    [currentActivity],
  );

  const debounceSaveScreenSettings = useCallback(
    debounce(
      (activity, currentActivity, group) => {
        console.log('SAVING ACTIVITY:', { activity });
        dispatch(saveActivity({ activity }));
        dispatch(upsertActivity({ activity }));

        if (activity.title !== currentActivity?.title) {
          dispatch(updateSequenceItemFromActivity({ activity: activity, group: group }));
          dispatch(savePage());
        }
      },
      500,
      { maxWait: 10000, leading: false },
    ),
    [],
  );

  const debounceSavePage = useCallback(
    debounce(
      (changes) => {
        console.log('SAVING PAGE', { changes });
        // update server
        dispatch(savePage(changes));
        // update redux
        // TODO: check if revision slug changes?
        dispatch(updatePage(changes));
      },
      500,
      { maxWait: 10000, leading: false },
    ),
    [],
  );

  const lessonPropertyChangeHandler = (properties: any) => {
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
    console.log('LESSON PROP CHANGED', { modelChanges, lessonChanges, properties });

    // need to put a healthy debounce in here, this fires every keystroke
    // save the page
    debounceSavePage(lessonChanges);
  };

  const debounceSavePartComponent = useCallback(
    debounce(
      (activity) => {
        console.log('SAVING ACTIVITY (PART COMPONENT):', { activity });
        dispatch(saveActivity({ activity }));
        dispatch(upsertActivity({ activity }));
      },
      500,
      { maxWait: 10000, leading: false },
    ),
    [],
  );

  const [currentComponentData, setCurrentComponentData] = useState<any>(null);
  const [currentPartInstance, setCurrentPartInstance] = useState<any>(null);
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
    console.log('part selected', { partDef });
    if (partDef) {
      // part component should be registered by type as a custom element
      const PartClass = customElements.get(partDef.type);
      if (PartClass) {
        const instance = new PartClass();

        setCurrentPartInstance(instance);

        let data = partDef;
        if (instance.transformModelToSchema) {
          // because the part schema below only knows about the "custom" block
          data.custom = instance.transformModelToSchema(partDef.custom);
        }
        data = transformPartModelToSchema(data);
        setCurrentComponentData(data);

        // schema
        if (instance.getSchema) {
          const customPartSchema = instance.getSchema();
          const newSchema = {
            ...partSchema,
            properties: {
              ...partSchema.properties,
              custom: { type: 'object', properties: { ...customPartSchema } },
            },
          };
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
          const customPartSchema = instance.getSchema();
          if (customPartSchema.palette) {
            newUiSchema.custom = {
              ...newUiSchema.custom,
              palette: {
                'ui:ObjectFieldTemplate': CustomFieldTemplate,
                'ui:title': 'Palette',
                backgroundColor: {
                  'ui:widget': ColorPickerWidget,
                },
                borderColor: {
                  'ui:widget': ColorPickerWidget,
                },
                borderStyle: { classNames: 'col-6' },
                borderWidth: { classNames: 'col-6' },
              },
            };
          }
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
  }, [currentPartSelection]);

  const componentPropertyChangeHandler = (properties: any) => {
    let modelChanges = properties;
    if (currentPartInstance && currentPartInstance.transformSchemaToModel) {
      modelChanges.custom = currentPartInstance.transformSchemaToModel(properties);
    }
    modelChanges = transformPartSchemaToModel(modelChanges);
    console.log('COMPONENT PROP CHANGED', { properties, modelChanges });

    const cloneActivity = clone(currentActivity);
    const ogPart = cloneActivity.content?.partsLayout.find((part: any) => part.id === modelChanges.id);
    if (!ogPart) {
      // hopefully UI will prevent this from happening
      console.warn('couldnt find part in current activity, most like lives on a layer; you need to update they layer copy directly');
      return;
    }
    ogPart.custom = modelChanges.custom;

    debounceSavePartComponent(cloneActivity);
  };

  return (
    <Tabs
      className="aa-panel-section-title-bar aa-panel-tabs"
      activeKey={selectedTab}
      onSelect={handleSelectTab}
    >
      <Tab eventKey={RightPanelTabs.LESSON} title="Lesson">
        <div className="lesson-tab">
          <PropertyEditor
            schema={lessonSchema as JSONSchema7}
            uiSchema={lessonUiSchema}
            value={lessonData}
            onChangeHandler={lessonPropertyChangeHandler}
          />
        </div>
      </Tab>
      <Tab eventKey={RightPanelTabs.SCREEN} title="Screen">
        <div className="screen-tab p-3">
          {currentActivity && screenData ? (
            <PropertyEditor
              key={currentActivity.id}
              schema={screenSchema as JSONSchema7}
              uiSchema={screenUiSchema}
              value={screenData}
              onChangeHandler={screenPropertyChangeHandler}
            />
          ) : null}
        </div>
      </Tab>
      <Tab eventKey={RightPanelTabs.COMPONENT} title="Component" disabled={!currentComponent}>
        {currentComponent && currentComponentData && (
          <div className="commponent-tab p-3">
            <PropertyEditor
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
export default RightMenu;
