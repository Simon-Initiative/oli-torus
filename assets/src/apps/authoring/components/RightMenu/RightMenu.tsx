import React, { useState } from 'react';
import { Tab, Tabs } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { selectCurrentActivity } from '../../../delivery/store/features/activities/slice';
import { selectState as selectPageState } from '../../store/page/slice';
import PropertyEditor from '../PropertyEditor/PropertyEditor';
import lessonSchema from '../PropertyEditor/schemas/lesson';
import screenSchema from '../PropertyEditor/schemas/screen';
import { JSONSchema7 } from 'json-schema';

const RightMenu: React.FC<any> = (props) => {
  const [selectedTab, setSelectedTab] = useState<string>('lesson');
  const currentActivity = useSelector(selectCurrentActivity);
  const currentLesson = useSelector(selectPageState);

  console.log('CURRENT', { currentActivity, currentLesson });

  // TODO: dynamically load schema from Part Component configuration
  const componentSchema: JSONSchema7 = { type: 'object' };
  const currentComponent = null;

  const handleSelectTab = (key: string) => {
    // TODO: any other saving or whatever
    setSelectedTab(key);
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
          value={currentLesson}
          onChangeHandler={props.onChangeHandler}
        />
      </Tab>
      <Tab eventKey="screen" title="Screen">
        <PropertyEditor
          schema={screenSchema}
          value={currentActivity?.model.custom}
          onChangeHandler={props.onChangeHandler}
        />
      </Tab>
      <Tab eventKey="component" title="Component" disabled={!currentComponent}>
        {currentComponent && (
          <PropertyEditor
            schema={componentSchema}
            value={currentComponent}
            onChangeHandler={props.onChangeHandler}
          />
        )}
      </Tab>
    </Tabs>
  );
};
export default RightMenu;
