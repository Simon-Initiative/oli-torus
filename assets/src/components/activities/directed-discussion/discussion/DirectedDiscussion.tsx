import React, { useMemo } from 'react';
//import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDelivery';
//import { castPartId } from '../../common/utils';
import { DirectedDiscussionActivitySchema } from '../schema';
import { DiscussionParticipation } from './DiscussionParticipation';
import { DiscussionSearchResults } from './DiscussionSearchResults';
import { DiscussionSearchSortBar } from './DiscussionSearchSortBar';
import { DiscussionThread } from './DiscussionThread';
import { useDiscussion } from './discussion-hook';
import { calculateParticipation } from './participation-util';

interface Props {
  sectionSlug: string;
  resourceId: number;
  model: DirectedDiscussionActivitySchema;
}

export const DirectedDiscussion: React.FC<Props> = ({ sectionSlug, resourceId, model }) => {
  const [searchTerm, setSearchTerm] = React.useState('');
  const [focusId, setFocusId] = React.useState<number | null>(null);

  const { loading, posts, addPost, currentUserId, deletePost } = useDiscussion(
    sectionSlug,
    resourceId,
  );

  const currentParticipation = useMemo(
    () => calculateParticipation(model.participation, posts, currentUserId),
    [posts, currentUserId],
  );

  if (!currentUserId) {
    return <div>Loading Discussion...</div>;
  }

  const onSearch = (search: string) => {
    setSearchTerm(search);
    setFocusId(null);
  };

  const hasSearchTerm = !!searchTerm && searchTerm.length > 0;
  const hasFocusId = focusId !== null;

  const displaySearchResults = !hasFocusId && hasSearchTerm;
  const displayThreads = !displaySearchResults;

  return (
    <div className="activity mc-activity">
      <div className="activity-content relative">
        <h2>Discussion</h2>
        <StemDeliveryConnected />
        <DiscussionParticipation
          requirements={model.participation}
          participation={currentParticipation}
          currentUserId={currentUserId}
        />
        <DiscussionSearchSortBar onSearch={onSearch} />
        {displaySearchResults && (
          <DiscussionSearchResults
            searchTerm={searchTerm}
            posts={posts}
            onFocus={(id) => setFocusId(id)}
          />
        )}
        {displayThreads && (
          <DiscussionThread
            focusId={focusId}
            canPost={currentParticipation.canPost}
            canReply={currentParticipation.canReply}
            posts={posts}
            onPost={addPost}
            currentUserId={currentUserId}
            onDeletePost={deletePost}
            maxWords={model.participation.maxWordLength}
          />
        )}

        {/* <HintsDeliveryConnected
          partId={castPartId(activityState.parts[0].partId)}
          resetPartInputs={{ [activityState.parts[0].partId]: [] }}
          shouldShow
        /> */}
        {loading && (
          <div className="inline p-2 fixed bottom-1 right-1 bg-gray-600 rounded-md text-white">
            Working...
          </div>
        )}
      </div>
    </div>
  );
};
