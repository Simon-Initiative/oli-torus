import React, { Fragment, useState } from 'react';
// import { Button, Icon, Input, List } from 'semantic-ui-react';

const ActionNavigationEditor = (props: any) => {
  const { action, onChange } = props;

  const [target, setTarget] = useState(action?.params?.target || '');

  const handleTargetChange = (e: any) => {
    const currentVal = e.target.value;
    setTarget(currentVal);
    onChange({ target: currentVal });
  };

  return (
    <div>ActionNavigationEditor coming soon</div>
    // <Fragment>
    //   <Icon name="compass" size="large" />
    //   <List.Content>
    //     Navigate To: <Input defaultValue={target} onBlur={handleTargetChange} />
    //     {/* <Button circular icon="bullseye" /> */}
    //   </List.Content>
    // </Fragment>
  );
};

export default ActionNavigationEditor;
