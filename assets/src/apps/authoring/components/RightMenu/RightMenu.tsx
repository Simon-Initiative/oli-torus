import { JSONSchema7 } from 'json-schema';
import React, { useState } from 'react';
import { Tab, Tabs } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { selectCurrentActivity } from '../../../delivery/store/features/activities/slice';
import { selectState as selectPageState } from '../../store/page/slice';
import PropertyEditor from '../PropertyEditor/PropertyEditor';
import lessonSchema, { lessonUiSchema } from '../PropertyEditor/schemas/lesson';
import screenSchema, { getScreenData, screenUiSchema } from '../PropertyEditor/schemas/screen';

const RightMenu: React.FC<any> = (props) => {
  const [selectedTab, setSelectedTab] = useState<string>('lesson');
  const currentActivity = useSelector(selectCurrentActivity);
  const currentLesson = useSelector(selectPageState);

  /* console.log('CURRENT', { currentActivity, currentLesson }); */

  // TODO: dynamically load schema from Part Component configuration
  const componentSchema: JSONSchema7 = { type: 'object' };
  const currentComponent = null;
  const screenData = getScreenData(currentActivity?.content?.custom);
  const handleSelectTab = (key: string) => {
    // TODO: any other saving or whatever
    setSelectedTab(key);
  };

  const screenPropertyChangeHandler = (properties: any) => {
    //console.log(properties);
  };
  const lessonPropertyChangeHandler = (properties: any) => {
    console.log(properties);
  };
  const componentPropertyChangeHandler = (properties: any) => {
    //console.log(properties);
  };
  return (
    <Tabs
      className="aa-panel-section-title-bar aa-panel-tabs"
      activeKey={selectedTab}
      onSelect={handleSelectTab}
    >
      <Tab eventKey="lesson" title="Lesson">
        <PropertyEditor
          schema={lessonSchema}
          uiSchema={lessonUiSchema}
          value={currentLesson}
          onChangeHandler={lessonPropertyChangeHandler}
        />
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
