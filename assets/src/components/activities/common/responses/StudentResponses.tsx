import React from 'react';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { LabelledChoices } from 'components/activities/common/choices/delivery/LabelledChoices';
import { defaultWriterContext } from 'data/content/writers/context';

interface StudentResponsesProps {
  model: any;
  projectSlug?: string;
  children?: React.ReactNode;
}

export const StudentResponses: React.FC<StudentResponsesProps> = ({ model, projectSlug, children }) => {
  const writerContext = defaultWriterContext({
    projectSlug: projectSlug || '',
  });

  // Determine if this is a choice-based activity (MCQ, CATA, or Ordering)
  const isChoiceBasedActivity = () => {
    return model.choices && Array.isArray(model.choices) && model.choices.length > 0;
  };

  return (
    <div className="d-flex" style={{ height: '100%' }}>
      {/* First column - 1/4 width */}
      <div style={{ width: '25%', height: '100%', borderRight: '1px solid #d3d3d3', paddingRight: '15px', marginRight: '15px' }}>
        {children || (
          <div className="text-muted">
            Student responses controls placeholder
          </div>
        )}
      </div>

      {/* Second column - 3/4 width */}
      <div style={{ width: '75%', height: '100%' }} className="pl-3">
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