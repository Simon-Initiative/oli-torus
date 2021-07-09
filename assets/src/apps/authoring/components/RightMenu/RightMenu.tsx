import { JSONSchema7 } from 'json-schema';
import React, { useState } from 'react';
import { Accordion, Tab, Tabs } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { selectCurrentActivity } from '../../../delivery/store/features/activities/slice';
import { selectState as selectPageState } from '../../store/page/slice';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';
import PropertyEditor from '../PropertyEditor/PropertyEditor';
import lessonSchema, {
  lessonUiSchema,
  transformModelToSchema as transformLessonModel,
} from '../PropertyEditor/schemas/lesson';
import screenSchema, { getScreenData, screenUiSchema } from '../PropertyEditor/schemas/screen';

const RightMenu: React.FC<any> = (props) => {
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

  const lessonPropertyChangeHandler = (properties: any) => {
    console.log('LESSON PROP CHANGED', { properties });
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
        <Accordion className="aa-lesson-properties-editor" defaultActiveKey="0">
          <div className="aa-panel-section-title-bar">
            <div className="d-flex align-items-center">
              <ContextAwareToggle eventKey="0" />
              <span className="title">Properties</span>
            </div>
          </div>
          <Accordion.Collapse eventKey="0">
            <PropertyEditor
              schema={lessonSchema}
              uiSchema={lessonUiSchema}
              value={lessonData}
              onChangeHandler={lessonPropertyChangeHandler}
            />
          </Accordion.Collapse>
        </Accordion>
        <Accordion className="aa-lesson-script-editor" defaultActiveKey="0">
          <div className="aa-panel-section-title-bar">
            <div className="d-flex align-items-center">
              <ContextAwareToggle eventKey="0" />
              <span className="title">Custom Logic</span>
            </div>
          </div>
          <Accordion.Collapse eventKey="0">
            <p>Property Editor for Variables and Custom Scripting</p>
          </Accordion.Collapse>
        </Accordion>
      </Tab>
      <Tab eventKey="screen" title="Screen">
        <PropertyEditor
          schema={screenSchema}
          uiSchema={screenUiSchema}
          value={screenData}
          onChangeHandler={screenPropertyChangeHandler}
        />
      </Tab>
      <Tab eventKey="component" title="Component" disabled={!currentComponent}>
        {currentComponent && (
          <PropertyEditor
            schema={componentSchema}
            uiSchema={{}}
            value={currentComponent}
            onChangeHandler={componentPropertyChangeHandler}
          />
        )}
      </Tab>
    </Tabs>
  );
};
export default RightMenu;
