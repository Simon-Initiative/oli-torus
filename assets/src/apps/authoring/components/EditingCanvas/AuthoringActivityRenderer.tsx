import { saveActivity } from 'apps/authoring/store/activities/actions/saveActivity';
import { setRightPanelActiveTab } from 'apps/authoring/store/app/slice';
import { selectCurrentSelection, setCurrentSelection } from 'apps/authoring/store/parts/slice';
import { ActivityModelSchema } from 'components/activities/types';
import React, { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { RightPanelTabs } from '../RightMenu/RightMenu';

interface AuthoringActivityRendererProps {
  activityModel: ActivityModelSchema;
  editMode: boolean;
  onSelectPart?: (partId: string) => Promise<any>;
  onCopyPart?: (part: any) => Promise<any>;
  onPartChangePosition?: (activityId: string, partId: string, dragData: any) => Promise<any>;
}

// the authoring activity renderer should be capable of handling *any* activity type, not just adaptive
// most events should be simply bubbled up to the layout renderer for handling
const AuthoringActivityRenderer: React.FC<AuthoringActivityRendererProps> = ({
  activityModel,
  editMode,
  onSelectPart,
  onCopyPart,
  onPartChangePosition,
}) => {
  const dispatch = useDispatch();
  const [isReady, setIsReady] = useState(false);

  const selectedPartId = useSelector(selectCurrentSelection);

  if (!activityModel.authoring || !activityModel.activityType) {
    console.warn('Bad Activity Data', activityModel);
    return null;
  }

  const elementProps = {
    id: `activity-${activityModel.id}`,
    model: JSON.stringify(activityModel),
    editMode,
    style: {
      position: 'absolute',
      top: '65px',
      left: '300px',
      paddingRight: '300px',
      paddingBottom: '300px',
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
        if (payload.eventName === 'copyPart' && onCopyPart) {
          result = await onCopyPart(payload.payload.copiedPart);
        }
        if (payload.eventName === 'dragPart' && onPartChangePosition) {
          result = await onPartChangePosition(
            payload.payload.activityId,
            payload.payload.partId,
            payload.payload.dragData,
          );
        }
        if (continuation) {
          continuation(result);
        }
      }
    };
    // for now just do this, todo we need to setup events and listen
    document.addEventListener('customEvent', customEventHandler);

    const handleActivityEdit = async (e: any) => {
      const target = e.target as HTMLElement;
      if (target?.id === elementProps.id) {
        const { model } = e.detail;
        console.log('AAR handleActivityEdit', { model });
        dispatch(saveActivity({ activity: model }));
        // why were we clearing the selection on edit?...
        // dispatch(setCurrentSelection({ selection: '' }));
        // dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
      }
    };
    document.addEventListener('modelUpdated', handleActivityEdit);
    setIsReady(true);

    return () => {
      document.removeEventListener('customEvent', customEventHandler);
      document.removeEventListener('modelUpdated', handleActivityEdit);
    };
  }, []);

  return isReady
    ? React.createElement(activityModel.activityType?.authoring_element, elementProps, null)
    : null;
};

export default AuthoringActivityRenderer;
