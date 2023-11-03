import { ActivityModelSchema, Part, Stem, Transformation } from '../types';

export interface DDParticipationDefinition {
  minPosts: number;
  maxPosts: number;
  minReplies: number;
  maxReplies: number;
  postDeadline?: string;
  replyDeadline?: string;
}

export interface DirectedDiscussionActivitySchema extends ActivityModelSchema {
  stem: Stem;

  authoring: {
    version: 1;
    parts: Part[];
    maxWords: number;
    participation: DDParticipationDefinition;
    transformations: Transformation[];
  };
}
