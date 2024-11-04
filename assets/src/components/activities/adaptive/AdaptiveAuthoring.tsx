import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import EventEmitter from 'events';
import flatten from 'lodash/flatten';
import uniq from 'lodash/uniq';
import { AnyPartComponent } from 'components/parts/types/parts';
import { getReferencedKeysInConditions } from 'adaptivity/rules-engine';
import {
  NotificationContext,
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { clone } from 'utils/common';
import { ModalContainer } from '../../../apps/authoring/components/AdvancedAuthoringModal';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import * as ActivityTypes from '../types';
import './AdaptiveAuthoring.scss';
import LayoutEditor from './components/authoring/LayoutEditor';
import { AdaptiveModelSchema } from './schema';

const Adaptive = (
  props: AuthoringElementProps<AdaptiveModelSchema> & { hostRef?: HTMLElement },
) => {
  // we create this to be able to further send down notifcations that came from the parent notifier
  const [pusher, _setPusher] = useState(new EventEmitter().setMaxListeners(50));

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
      NotificationType.CHECK_SHORTCUT_ACTIONS,
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
      /* console.log('Layout Change!', { parts }); */
      const modelClone = clone(props.model);
      modelClone.content.partsLayout = parts;
      // lets check if CAPI - configData has any variable that contains any expression.
      const conditionWithExpression: string[] = [];
      const iFrameParts = parts.filter((part) => part.type === 'janus-capi-iframe');
      iFrameParts?.forEach((part) => {
        const configDetails = part.custom.configData;
        const conditions = configDetails.map((data: any) => {
          return { target: `stage.${part.id}.${data.key}`, value: data.value };
        });
        if (conditions?.length) {
          conditionWithExpression.push(...getReferencedKeysInConditions(conditions, true));
        }
        if (!modelClone.content.custom.conditionsRequiredEvaluation) {
          modelClone.content.custom.conditionsRequiredEvaluation = [];
        }
        modelClone.content.custom.conditionsRequiredEvaluation.push(conditionWithExpression);
        modelClone.content.custom.conditionsRequiredEvaluation = uniq(
          flatten([...new Set(modelClone.content.custom.conditionsRequiredEvaluation)]),
        );
      });
      console.log({ modelClone });

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
        const _result = await props.onCustomEvent('selectPart', {
          activityId: props.model.id,
          id: partId,
        });
        /* console.log('got result from onSelect', result); */
      }
    },
    [props.onCustomEvent, props.editMode, selectedPartId],
  );

  const handleCopyComponent = useCallback(
    async (selectedPart: any) => {
      /* console.log('AUTHOR PART COPY', { selectedPart }); */
      if (props.onCustomEvent) {
        const _result = await props.onCustomEvent('copyPart', {
          activityId: props.model.id,
          copiedPart: selectedPart,
        });
      }
      //dispatch(setCopiedPart({ copiedPart: selectedPart }));
    },
    [props.onCustomEvent],
  );

  const handleConfigurePart = useCallback(
    async (part: any, context: any) => {
      /* console.log('[AdaptiveAuthoring] PART CONFIGURE', { part, context }); */
      if (props.onCustomEvent) {
        const _result = await props.onCustomEvent('configurePart', {
          activityId: props.model.id,
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
        const _result = await props.onCustomEvent('cancelConfigurePart', {
          activityId: props.model.id,
          partId,
        });
      }
    },
    [props.onCustomEvent],
  );

  return (
    <NotificationContext.Provider value={pusher}>
      <ModalContainer>
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
      </ModalContainer>
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
