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
import {
  selectCurrentActivity,
  upsertActivity,
} from '../../../delivery/store/features/activities/slice';
import { saveActivity } from '../../store/activities/actions/saveActivity';
import { savePage } from '../../store/page/actions/savePage';
import { selectState as selectPageState, updatePage } from '../../store/page/slice';
import PropertyEditor from '../PropertyEditor/PropertyEditor';
import lessonSchema, {
  lessonUiSchema,
  transformModelToSchema as transformLessonModel,
  transformSchemaToModel as transformLessonSchema,
} from '../PropertyEditor/schemas/lesson';
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
  const currentActivity = useSelector(selectCurrentActivity);
  const currentLesson = useSelector(selectPageState);

  // TODO: dynamically load schema from Part Component configuration
  const componentSchema: JSONSchema7 = { type: 'object' };
  const currentComponent = null;

  const [screenData, setScreenData] = useState(
    transformScreenModeltoSchema(currentActivity?.content?.custom),
  );
  useEffect(() => {
    console.log('CURRENT', { currentActivity, currentLesson });
    setScreenData(transformScreenModeltoSchema(currentActivity?.content?.custom));
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
        console.log('Screen Property Change...', { modelChanges });
        const screenChanges = {
          ...currentActivity?.content?.custom,
          ...modelChanges,
        };
        const cloneActivity = clone(currentActivity);
        cloneActivity.content.custom = screenChanges;
        debounceSaveScreenSettings(cloneActivity);
      }
    },
    [currentActivity],
  );

  const debounceSaveScreenSettings = useCallback(
    debounce(
      (activity) => {
        console.log('SAVING ACTIVITY:', { activity });
        dispatch(saveActivity({ activity }));
        dispatch(upsertActivity({ activity }));
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
    console.log('LESSON PROP CHANGED', { modelChanges, lessonChanges, properties });

    // need to put a healthy debounce in here, this fires every keystroke
    // save the page
    debounceSavePage(lessonChanges);
  };

  const componentPropertyChangeHandler = (properties: any) => {
    console.log('COMPONENT PROP CHANGED', { properties });
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
          {currentActivity ? (
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
        {currentComponent && (
          <div className="commponent-tab">
            <PropertyEditor
              schema={componentSchema}
              uiSchema={{}}
              value={currentComponent}
              onChangeHandler={componentPropertyChangeHandler}
            />
          </div>
        )}
      </Tab>
    </Tabs>
  );
};
export default RightMenu;
