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
        className={`px-3 py-3 text-base text-white ${
          disabled
            ? 'opacity-50 cursor-not-allowed'
            : 'hover:bg-gray-300 hover:scale-105 active:scale-95 transition-transform duration-150 cursor-pointer'
        } rounded`}
        onClick={onClick}
      >
        <img
          src="/images/icons/icon-AI.svg"
          style={{ marginBottom: 0 }}
          className="block w-6 h-6 m-0 p-0"
        />
      </button>
    </div>
  );
});

TriggerButton.displayName = 'TriggerButton';
