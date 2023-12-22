import React from 'react';
import { Card } from 'components/misc/Card';
import { useAuthoringElementContext } from '../../AuthoringElementProvider';
import { ParticipationInput } from '../ParticipationInput';
import { DirectedDiscussionActions } from '../actions';
import { DDParticipationDefinition, DirectedDiscussionActivitySchema } from '../schema';

export const DiscussionParticipationAuthoring: React.FC = () => {
  const { model, dispatch, editMode } =
    useAuthoringElementContext<DirectedDiscussionActivitySchema>();

  const { minPosts, maxPosts, minReplies, maxReplies, maxWordLength } = model.participation;

  const onChangeParticipation =
    (field: keyof DDParticipationDefinition) => (value: number | string) => {
      dispatch(
        DirectedDiscussionActions.editParticipation({
          ...model.participation,
          [field]: value,
        }),
      );
    };

  return (
    <Card.Card>
      <Card.Title>
        <h2>Participation Requirements</h2>
      </Card.Title>
      <Card.Content>
        <ParticipationInput
          value={minPosts}
          onChange={onChangeParticipation('minPosts')}
          editMode={editMode}
        >
          Required number of posts:
        </ParticipationInput>
        <ParticipationInput
          value={maxPosts}
          onChange={onChangeParticipation('maxPosts')}
          editMode={editMode}
        >
          Maximum number of posts:
        </ParticipationInput>
        <ParticipationInput
          value={minReplies}
          onChange={onChangeParticipation('minReplies')}
          editMode={editMode}
        >
          Required number of replies:
        </ParticipationInput>
        <ParticipationInput
          value={maxReplies}
          onChange={onChangeParticipation('maxReplies')}
          editMode={editMode}
        >
          Maximum number of replies:
        </ParticipationInput>
        <ParticipationInput
          value={maxWordLength}
          onChange={onChangeParticipation('maxWordLength')}
          editMode={editMode}
        >
          Maximum number of words:
        </ParticipationInput>
        {/* <ParticipationDateInput
          value={postDeadline}
          onChange={onChangeParticipation('postDeadline')}
          editMode={editMode}
        >
          Post deadline:
        </ParticipationDateInput>
        <ParticipationDateInput
          value={replyDeadline}
          onChange={onChangeParticipation('replyDeadline')}
          editMode={editMode}
        >
          Reply deadline:
        </ParticipationDateInput> */}
      </Card.Content>
    </Card.Card>
  );
};
