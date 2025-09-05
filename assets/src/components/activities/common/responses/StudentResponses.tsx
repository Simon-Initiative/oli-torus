import React from 'react';
import { LabelledChoices } from 'components/activities/common/choices/delivery/LabelledChoices';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { defaultWriterContext } from 'data/content/writers/context';

interface StudentResponsesProps {
  model: any;
  projectSlug?: string;
  children?: React.ReactNode;
}

export const StudentResponses: React.FC<StudentResponsesProps> = ({
  model,
  projectSlug,
  children,
}) => {
  const writerContext = defaultWriterContext({
    projectSlug: projectSlug || '',
  });

  // Determine if this is a choice-based activity (MCQ, CATA, or Ordering)
  const isChoiceBasedActivity = () => {
    return model.choices && Array.isArray(model.choices) && model.choices.length > 0;
  };

  return (
    <div className="flex h-full">
      {/* Fixed width column for visualization - 280px to accommodate 250px chart + padding */}
      <div className="w-[280px] h-full border-r border-gray-300 pr-4 mr-4 flex-shrink-0">
        {children || <div className="text-muted">Student responses controls placeholder</div>}
      </div>

      {/* Remaining space for content */}
      <div className="flex-1 h-full pl-3 min-w-0">
        <StemDelivery stem={model.stem} context={writerContext} />
        {isChoiceBasedActivity() && (
          <div className="mt-3">
            <LabelledChoices choices={model.choices} />
          </div>
        )}
      </div>
    </div>
  );
};
