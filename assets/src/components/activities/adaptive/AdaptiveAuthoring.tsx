import {
  NotificationContext,
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { AnyPartComponent } from 'components/parts/types/parts';
import EventEmitter from 'events';
import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { clone } from 'utils/common';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import * as ActivityTypes from '../types';
import LayoutEditor from './components/authoring/LayoutEditor';
import { AdaptiveModelSchema } from './schema';

const Adaptive = (
  props: AuthoringElementProps<AdaptiveModelSchema> & { hostRef?: HTMLElement },
) => {
  // we create this to be able to further send down notifcations that came from the parent notifier
  const [pusher, setPusher] = useState(new EventEmitter().setMaxListeners(50));

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
      NotificationType.CONFIGURE,
      NotificationType.CONFIGURE_CANCEL,
      NotificationType.CONFIGURE_SAVE,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (e: any) => {
        // for now we will just forward the notification to the context
        pusher.emit(notificationType.toString(), e);
      };
      const unsub = subscribeToNotification(
        props.notify as EventEmitter,
        notificationType,
        handler,
      );
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify]);

  const [selectedPartId, setSelectedPartId] = useState('');
  const [configurePortalId, setConfigurePortalId] = useState('');
  const [parts, setParts] = useState<any[]>(props.model?.content?.partsLayout || []);

  // this effect keeps the local parts state in sync with the props
  useEffect(() => {
    setParts(props.model?.content?.partsLayout || []);
  }, [props.model?.content?.partsLayout]);

  // this effect sets the selection from the outside based on authoring context
  useEffect(() => {
    if (props.authoringContext) {
      /* console.log('[AdaptiveAuthoring] AuthoringContext: ', props.authoringContext); */
      setSelectedPartId(props.authoringContext.selectedPartId);
      setConfigurePortalId(props.authoringContext.configurePortalId || '');
    }
  }, [props.authoringContext]);

  const handleLayoutChange = useCallback(
    async (parts: AnyPartComponent[]) => {
      /* console.log('Layout Change!', parts); */
      const modelClone = clone(props.model);
      modelClone.content.partsLayout = parts;
      props.onEdit(modelClone);
    },
    [props.model],
  );

  const handlePartSelect = useCallback(
    async (partId: string) => {
      if (!props.editMode) {
        return;
      }
      setSelectedPartId(partId);
      if (props.onCustomEvent) {
        const result = await props.onCustomEvent('selectPart', { id: partId });
        /* console.log('got result from onSelect', result); */
      }
    },
    [props.onCustomEvent, props.editMode, selectedPartId],
  );

  const handleCopyComponent = useCallback(
    async (selectedPart: any) => {
      /* console.log('AUTHOR PART COPY', { selectedPart }); */
      if (props.onCustomEvent) {
        const result = await props.onCustomEvent('copyPart', { copiedPart: selectedPart });
      }
      //dispatch(setCopiedPart({ copiedPart: selectedPart }));
    },
    [props.onCustomEvent],
  );

  const handleConfigurePart = useCallback(
    async (part: any, context: any) => {
      /* console.log('[AdaptiveAuthoring] PART CONFIGURE', { part, context }); */
      if (props.onCustomEvent) {
        const result = await props.onCustomEvent('configurePart', {
          part,
          context,
        });
      }
    },
    [props.onCustomEvent],
  );

  const handleCancelConfigurePart = useCallback(
    async (partId: string) => {
      /* console.log('AUTHOR PART CANCEL CONFIGURE', { partId }); */
      if (props.onCustomEvent) {
        const result = await props.onCustomEvent('cancelConfigurePart', {
          partId,
        });
      }
    },
    [props.onCustomEvent],
  );

  return (
    <NotificationContext.Provider value={pusher}>
      <LayoutEditor
        id={props.model.id || ''}
        hostRef={props.hostRef}
        width={props.model.content?.custom?.width || 1000}
        height={props.model.content?.custom?.height || 500}
        backgroundColor={props.model.content?.custom?.palette.backgroundColor || '#fff'}
        selected={selectedPartId}
        parts={parts}
        onChange={handleLayoutChange}
        onCopyPart={handleCopyComponent}
        onConfigurePart={handleConfigurePart}
        onCancelConfigurePart={handleCancelConfigurePart}
        configurePortalId={configurePortalId}
        onSelect={handlePartSelect}
      />
    </NotificationContext.Provider>
  );
};

export class AdaptiveAuthoring extends AuthoringElement<AdaptiveModelSchema> {
  props() {
    const superProps = super.props();
    return {
      ...superProps,
      hostRef: this,
    };
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<AdaptiveModelSchema>) {
    ReactDOM.render(<Adaptive {...props} />, mountPoint);
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, AdaptiveAuthoring);
