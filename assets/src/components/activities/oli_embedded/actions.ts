import { Maybe } from 'tsmonad';
import { Identifiable } from 'data/content/model/other';
import { makeUndoable, PostUndoable, ScoringStrategy } from 'components/activities/types';
import { OliEmbeddedModelSchema } from 'components/activities/oli_embedded/schema';
import { Operations } from 'utils/pathOperations';
import { clone } from 'utils/common';
import guid from 'utils/guid';

export class OliEmbeddedActions {
  private static getById<T extends Identifiable>(slice: T[], id: string): Maybe<T> {
    return Maybe.maybe(slice.find((c) => c.id === id));
  }

  static editActivityXml(xml: string) {
    return (draftState: OliEmbeddedModelSchema, _post: PostUndoable) => {
      draftState.modelXml = xml;
    };
  }

  static addResourceURL(value: string) {
    return (draftState: OliEmbeddedModelSchema, _post: PostUndoable) => {
      if (draftState.resourceURLs.indexOf(value) === -1) {
        draftState.resourceURLs.push(value);
      }
    };
  }

  static addNewPart() {
    return (draftState: OliEmbeddedModelSchema, _post: PostUndoable) => {
      draftState.authoring.parts.push({
        id: guid(),
        scoringStrategy: ScoringStrategy.average,
        responses: [],
        hints: [],
      });
    };
  }

  static removePart(partId: string) {
    return (draftState: OliEmbeddedModelSchema, _post: PostUndoable) => {
      if (draftState.authoring.parts.length > 1) {
        draftState.authoring.parts = draftState.authoring.parts.filter((p) => p.id !== partId);
      }
    };
  }

  static updatePartScoringStrategy(partId: string, scoringStrategy: ScoringStrategy) {
    return (draftState: OliEmbeddedModelSchema, _post: PostUndoable) => {
      const part = draftState.authoring.parts.find((p) => p.id === partId);
      if (part) {
        part.scoringStrategy = scoringStrategy;
      }
    };
  }

  static removeResourceURL(value: string) {
    return (draftState: OliEmbeddedModelSchema, post: PostUndoable) => {
      const index = draftState.resourceURLs.findIndex((url) => url === value);
      const item = draftState.resourceURLs[index];
      post(
        makeUndoable('Removed a file', [Operations.insert('$.resourceURLs', clone(item), index)]),
      );

      draftState.resourceURLs = draftState.resourceURLs.filter((url) => url !== value);
    };
  }
}
