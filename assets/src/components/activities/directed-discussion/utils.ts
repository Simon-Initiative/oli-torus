import {
  makeHint,
  makePart,
  makeResponse,
  makeStem,
} from 'components/activities/types';
import { matchRule } from 'data/activities/model/rules';
import { DirectedDiscussionActivitySchema } from './schema';

export const defaultDDModel: () => DirectedDiscussionActivitySchema = () => {
  return {
    stem: makeStem(''),
    authoring: {
      version: 1,
      maxWords: 0,
      transformations: [],
      participation: {
        maxPosts: 0,
        maxReplies: 0,
        minPosts: 0,
        minReplies: 0,
      },
      parts: [
        makePart(
          [makeResponse(matchRule('.*'), 0, 'Default Part')],
          [makeHint(''), makeHint(''), makeHint('')],
          '1',
        ),
      ],
      targeted: [],
    },
  };
};
