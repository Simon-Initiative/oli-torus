import React, { ReactNode } from 'react';

import * as Trigger from 'data/persistence/trigger';
import * as TriggerModel from 'data/triggers';

export const TriggerGroupButton: React.FC<{
  trigger: TriggerModel.GroupTrigger
  resourceId: number;
  sectionSlug: string;
  children?: ReactNode;
}> = React.memo(({ trigger, resourceId, sectionSlug }) => {

  const onClick = () => {
    const payload: Trigger.TriggerPayload = {
      trigger_type: 'content_group',
      resource_id: resourceId,
      data: {ref_id: trigger.id},
      prompt: trigger.prompt,
    };
    Trigger.invoke(sectionSlug, payload);
  };

  return (
    <button
      className="px-2 py-1 text-sm text-white rounded active:scale-95 transition-transform"
      onClick={onClick}>
      <img src="/images/icons/icon-AI.svg" className="inline mr-1" />
    </button>
  );
});

TriggerGroupButton.displayName = 'TriggerGroupButton';
