import { makeHint, makePart, makeResponse, makeStem } from 'components/activities/types';
import { matchRule } from 'data/activities/model/rules';
import { DirectedDiscussionActivitySchema } from './schema';

export const defaultDDModel: () => DirectedDiscussionActivitySchema = () => {
  return {
    stem: makeStem(''),
    maxWords: 0,
    participation: {
      maxPosts: 0,
      maxReplies: 0,
      minPosts: 0,
      minReplies: 0,
      maxWordLength: 0,
    },
    authoring: {
      version: 1,
      transformations: [],
      parts: [
        makePart(
          [makeResponse(matchRule('.*'), 0, 'Default Part')],
          [makeHint(''), makeHint(''), makeHint('')],
          '1',
        ),
      ],
    },
  };
};
