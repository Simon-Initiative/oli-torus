import React from 'react';

interface Props {
  enabled: boolean;
  activityId: number;
}

export const DiscussionThread: React.FC<Props> = ({enabled, activityId}) => {
  if(!enabled) {
    return <DiscussionPreview />
  }
  return <div>Discussion Thread</div>;
};



const DiscussionPreview : React.FC = () => {
  // TODO - give a better preview
  return <div>
    Discussions not available in preview.
  </div>
}