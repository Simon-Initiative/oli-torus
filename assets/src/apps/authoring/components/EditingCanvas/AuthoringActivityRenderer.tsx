import React, { useEffect, useState } from 'react';
import { ActivityModelSchema } from 'components/activities/types';
import { useSelector } from 'react-redux';
import { selectCurrentSelection } from 'apps/authoring/store/parts/slice';

interface AuthoringActivityRendererProps {
  activityModel: ActivityModelSchema;
  editMode: boolean;
  onSelectPart?: (partId: string) => Promise<any>;
  onPartChangePosition?: (partId: string, x: number, y: number) => Promise<any>;
}

// the authoring activity renderer should be capable of handling *any* activity type, not just adaptive
// most events should be simply bubbled up to the layout renderer for handling
const AuthoringActivityRenderer: React.FC<AuthoringActivityRendererProps> = ({
  activityModel,
  editMode,
  onSelectPart,
  onPartChangePosition,
}) => {
  console.log('AAR', { activityModel });
  const [isReady, setIsReady] = useState(false);

  const selectedPartId = useSelector(selectCurrentSelection);

  const elementProps = {
    id: `activity-${activityModel.id}`,
    model: JSON.stringify(activityModel),
    editMode,
    style: {
      position: 'absolute',
      top: '10%',
      left: '25%',
    },
    authoringContext: JSON.stringify({
      selectedPartId,
    }),
  };

  useEffect(() => {
    const customEventHandler = async (e: any) => {
      const target = e.target as HTMLElement;
      if (target?.id === elementProps.id) {
        const { payload, continuation } = e.detail;
        let result = null;
        if (payload.eventName === 'selectPart' && onSelectPart) {
          result = await onSelectPart(payload.payload.id);
        }
        if (payload.eventName === 'dragPart' && onPartChangePosition) {
          result = await onPartChangePosition(
            payload.payload.id,
            payload.payload.x,
            payload.payload.y,
          );
        }
        if (continuation) {
          continuation(result);
        }
      }
    };
    // for now just do this, todo we need to setup events and listen
    document.addEventListener('customEvent', customEventHandler);
    setIsReady(true);

    return () => {
      document.removeEventListener('customEvent', customEventHandler);
    };
  }, [activityModel]);

  return isReady
    ? React.createElement(activityModel.activityType?.authoring_element, elementProps, null)
    : null;
};

export default AuthoringActivityRenderer;
