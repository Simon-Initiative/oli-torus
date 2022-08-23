import { saveActivity } from 'apps/authoring/store/activities/actions/saveActivity';
import { selectCurrentSelection } from 'apps/authoring/store/parts/slice';
import { NotificationType } from 'apps/delivery/components/NotificationContext';
import { ActivityModelSchema } from 'components/activities/types';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';

interface AuthoringActivityRendererProps {
  activityModel: ActivityModelSchema;
  editMode: boolean;
  configEditorId: string;
  onSelectPart?: (partId: string) => Promise<any>;
  onCopyPart?: (part: any) => Promise<any>;
  onConfigurePart?: (part: any, context: any) => Promise<any>;
  onCancelConfigurePart?: (partId: string) => Promise<any>;
  onSaveConfigurePart?: (partId: string) => Promise<any>;
  onPartChangePosition?: (activityId: string, partId: string, dragData: any) => Promise<any>;
  notificationStream?: { stamp: number; type: NotificationType; payload: any } | null;
}

// the authoring activity renderer should be capable of handling *any* activity type, not just adaptive
// most events should be simply bubbled up to the layout renderer for handling
const AuthoringActivityRenderer: React.FC<AuthoringActivityRendererProps> = ({
  activityModel,
  editMode,
  configEditorId,
  onSelectPart,
  onCopyPart,
  onConfigurePart,
  onCancelConfigurePart,
  onSaveConfigurePart,
  onPartChangePosition,
  notificationStream,
}) => {
  const dispatch = useDispatch();
  const [isReady, setIsReady] = useState(false);

  const selectedPartId = useSelector(selectCurrentSelection);

  const ref = useRef<any>(null);

  const elementProps = {
    id: `activity-${activityModel.id}`,
    ref,
    model: JSON.stringify(activityModel),
    editMode,
    style: {
      position: 'absolute',
      top: '65px',
      left: '300px',
      paddingRight: '300px',
      paddingBottom: '300px',
      pointerEvents: `${editMode ? 'auto' : 'none'}`,
    },
    authoringContext: JSON.stringify({
      selectedPartId,
      configurePortalId: configEditorId,
    }),
  };

  const sendNotify = useCallback(
    (type: NotificationType, payload: any) => {
      if (ref.current && ref.current.notify) {
        ref.current.notify(type, payload);
      }
    },
    [ref],
  );

  useEffect(() => {
    if (!activityModel.authoring || !activityModel.activityType) {
      return;
    }
    // the "notificationStream" is a state based way to "push" stuff into the activity
    // from here it uses the notification system which is an event emitter because
    // these are web components and not in the same react context, and
    // in order to send via props as state we would need to stringify the object
    if (notificationStream?.stamp) {
      sendNotify(notificationStream.type, notificationStream.payload);
    }
  }, [notificationStream]);

  useEffect(() => {
    if (!activityModel.authoring || !activityModel.activityType) {
      return;
    }
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
        if (payload.eventName === 'configurePart' && onConfigurePart) {
          result = await onConfigurePart(payload.payload.part, payload.payload.context);
        }
        if (payload.eventName === 'saveConfigurePart' && onSaveConfigurePart) {
          result = await onSaveConfigurePart(payload.payload.partId);
        }
        if (payload.eventName === 'cancelConfigurePart' && onCancelConfigurePart) {
          result = await onCancelConfigurePart(payload.payload.partId);
        }

        // DEPRECATED
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
        /* console.log('AAR handleActivityEdit', { model }); */
        dispatch(saveActivity({ activity: model, undoable: true }));
        // why were we clearing the selection on edit?...
        // dispatch(setCurrentSelection({ selection: '' }));
        // dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
      }
    };
    document.addEventListener('modelUpdated', handleActivityEdit);
    setIsReady(true);

    return () => {
      /* console.log('AAR: unmounting'); */
      document.removeEventListener('customEvent', customEventHandler);
      document.removeEventListener('modelUpdated', handleActivityEdit);
    };
  }, [elementProps.id]);

  if (!activityModel.authoring || !activityModel.activityType) {
    console.warn('Bad Activity Data', activityModel);
    return null;
  }

  return isReady
    ? React.createElement(activityModel.activityType?.authoring_element, elementProps, null)
    : null;
};

export default AuthoringActivityRenderer;
