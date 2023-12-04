import { ActivityModelSchema, Part, Stem, Transformation } from '../types';

export interface DDParticipationDefinition {
  minPosts: number;
  maxPosts: number;
  minReplies: number;
  maxReplies: number;
  maxWordLength: number;
}

export interface DirectedDiscussionActivitySchema extends ActivityModelSchema {
  stem: Stem;

  participation: DDParticipationDefinition;
  maxWords: number;

  authoring: {
    version: 1;
    parts: Part[];
    transformations: Transformation[];
  };
}
