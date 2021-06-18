import React, { useState } from 'react';
import { Tab, Tabs } from 'react-bootstrap';
import PropertyEditor from '../PropertyEditor/PropertyEditor';
import lessonSchema from '../PropertyEditor/schemas/lesson';
import screenSchema from '../PropertyEditor/schemas/screen';

const RightMenu: React.FC<any> = (props) => {
  const [selectedTab, setSelectedTab] = useState<string>('lesson');

  // TODO: dynamically load schema from Part Component configuration
  const componentSchema = {};

  const handleSelectTab = (key: string) => {
    // TODO: any other saving or whatever
    setSelectedTab(key);
  };

  return (
    <Tabs activeKey={selectedTab} onSelect={handleSelectTab}>
      <Tab eventKey="lesson" title="Lesson">
        <PropertyEditor schema={lessonSchema} />
      </Tab>
      <Tab eventKey="screen" title="Screen">
        <PropertyEditor schema={screenSchema} />
      </Tab>
      <Tab eventKey="component" title="Component" disabled>
        <PropertyEditor schema={componentSchema} />
      </Tab>
    </Tabs>
  );
};
export default RightMenu;
