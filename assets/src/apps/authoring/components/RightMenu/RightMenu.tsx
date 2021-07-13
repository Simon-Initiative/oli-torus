import { JSONSchema7 } from 'json-schema';
import { debounce } from 'lodash';
import React, { useCallback, useState } from 'react';
import { Accordion, Tab, Tabs } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivity } from '../../../delivery/store/features/activities/slice';
import { savePage } from '../../store/page/actions/savePage';
import { selectState as selectPageState, updatePage } from '../../store/page/slice';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';
import PropertyEditor from '../PropertyEditor/PropertyEditor';
import lessonSchema, {
  lessonUiSchema,
  transformModelToSchema as transformLessonModel,
  transformSchemaToModel as transformLessonSchema,
} from '../PropertyEditor/schemas/lesson';
import screenSchema, { getScreenData, screenUiSchema } from '../PropertyEditor/schemas/screen';

const RightMenu: React.FC<any> = (props) => {
  const dispatch = useDispatch();
  const [selectedTab, setSelectedTab] = useState<string>('lesson');
  const currentActivity = useSelector(selectCurrentActivity);
  const currentLesson = useSelector(selectPageState);

  console.log('CURRENT', { currentActivity, currentLesson });

  // TODO: dynamically load schema from Part Component configuration
  const componentSchema: JSONSchema7 = { type: 'object' };
  const currentComponent = null;

  const screenData = getScreenData(currentActivity?.content?.custom);
  const lessonData = transformLessonModel(currentLesson);

  const handleSelectTab = (key: string) => {
    // TODO: any other saving or whatever
    setSelectedTab(key);
  };

  const screenPropertyChangeHandler = (properties: any) => {
    console.log('SCREEN PROP CHANGED', { properties });
  };

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
      <Tab eventKey="lesson" title="Lesson">
        <div >
          <PropertyEditor
            schema={lessonSchema}
            uiSchema={lessonUiSchema}
            value={lessonData}
            onChangeHandler={lessonPropertyChangeHandler}
          />
        </div>
      </Tab>
      <Tab eventKey="screen" title="Screen">
        <div>
          <PropertyEditor
            schema={screenSchema}
            uiSchema={screenUiSchema}
            value={screenData}
            onChangeHandler={screenPropertyChangeHandler}
          />
        </div>
      </Tab>
      <Tab eventKey="component" title="Component" disabled={!currentComponent}>
        {currentComponent && (
          <div className="p-3">
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
