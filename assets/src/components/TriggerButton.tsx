import React, { ReactNode } from 'react';

import * as Trigger from 'data/persistence/trigger';
import * as ContentModel from '../data/content/model/elements/types';

export const TriggerButton: React.FC<{
  trigger: ContentModel.TriggerBlock;
  resourceId: number;
  sectionSlug: string;
  children?: ReactNode;
}> = React.memo(({ trigger, resourceId, sectionSlug }) => {

  const onClick = () => {
    const payload: Trigger.TriggerPayload = {
      trigger_type: 'content_block',
      resource_id: resourceId,
      data: trigger.id,
      prompt: trigger.prompt,
    };
    Trigger.invoke(sectionSlug, payload);
  };

  return (
    <button
      className="btn btn-primary"
      onClick={onClick}>
        Trigger
    </button>
  );
});

TriggerButton.displayName = 'TriggerButton';
