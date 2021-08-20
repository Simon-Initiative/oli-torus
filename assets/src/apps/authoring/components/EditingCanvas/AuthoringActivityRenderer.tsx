import React, { useEffect, useState } from 'react';
import { ActivityModelSchema } from 'components/activities/types';

interface AuthoringActivityRendererProps {
  activityModel: ActivityModelSchema;
  editMode: boolean;
}

// the authoring activity renderer should be capable of handling *any* activity type, not just adaptive
// most events should be simply bubbled up to the layout renderer for handling
const AuthoringActivityRenderer: React.FC<AuthoringActivityRendererProps> = ({
  activityModel,
  editMode,
}) => {
  console.log('AAR', { activityModel });
  const [isReady, setIsReady] = useState(false);

  const elementProps = {
    model: JSON.stringify(activityModel),
    editMode,
  };

  useEffect(() => {
    // for now just do this, todo we need to setup events and listen
    setIsReady(true);
  }, [activityModel]);

  return isReady
    ? React.createElement(activityModel.activityType?.authoring_element, elementProps, null)
    : null;
};

export default AuthoringActivityRenderer;