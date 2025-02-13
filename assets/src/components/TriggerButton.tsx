import React, { ReactNode, useState } from 'react';
import * as Trigger from 'data/persistence/trigger';
import * as ContentModel from '../data/content/model/elements/types';

export const TriggerButton: React.FC<{
  trigger: ContentModel.TriggerBlock;
  resourceId: number;
  sectionSlug: string;
  children?: ReactNode;
}> = React.memo(({ trigger, resourceId, sectionSlug }) => {
  const [disabled, setDisabled] = useState(false);
  const [delay, setDelay] = useState(5000);

  const onClick = () => {
    // Disable the button for 5 seconds after the student invokes the
    // trigger to prevent spamming. Double the delay each time the button
    // is clicked.
    setDisabled(true);
    setTimeout(() => setDisabled(false), delay);
    setDelay(delay * 2);

    const payload: Trigger.TriggerPayload = {
      trigger_type: 'content_block',
      resource_id: resourceId,
      data: { ref_id: trigger.id },
      prompt: trigger.prompt,
    };
    Trigger.invoke(sectionSlug, payload);
  };

  return (
    <div className="flex justify-center">
      <button
        disabled={disabled}
        className={`px-2 py-1 text-sm text-white ${
          disabled ? '' : 'active:scale-95 transition-transform'
        } rounded`}
        onClick={onClick}
      >
        <img src="/images/icons/icon-AI.svg" className="inline mr-1" />
      </button>
    </div>
  );
});

TriggerButton.displayName = 'TriggerButton';
