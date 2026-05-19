import { Maybe } from 'tsmonad';
import { OliEmbeddedModelSchema } from 'components/activities/oli_embedded/schema';
import { lastPart } from 'components/activities/oli_embedded/utils';
import { PostUndoable, ScoringStrategy, makeUndoable } from 'components/activities/types';
import { Identifiable } from 'data/content/model/other';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import { Operations } from 'utils/pathOperations';

export class OliEmbeddedActions {
  private static ensureResourceURLs(draftState: OliEmbeddedModelSchema) {
    if (!Array.isArray(draftState.resourceURLs)) {
      draftState.resourceURLs = [];
    }
  }

  static ensureAuthoringParts(draftState: OliEmbeddedModelSchema) {
    if (!draftState.authoring) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (draftState as any).authoring = { parts: [], previewText: '' };
    }

    if (!Array.isArray(draftState.authoring.parts)) {
      draftState.authoring.parts = [];
    }
  }

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
      OliEmbeddedActions.ensureResourceURLs(draftState);

      if (draftState.resourceURLs.indexOf(value) === -1) {
        draftState.resourceURLs.push(value);
      }
    };
  }

  static addNewPart() {
    return (draftState: OliEmbeddedModelSchema, _post: PostUndoable) => {
      OliEmbeddedActions.ensureAuthoringParts(draftState);

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
      OliEmbeddedActions.ensureAuthoringParts(draftState);

      if (draftState.authoring.parts.length > 1) {
        draftState.authoring.parts = draftState.authoring.parts.filter((p) => p.id !== partId);
      }
    };
  }

  static updatePartScoringStrategy(partId: string, scoringStrategy: ScoringStrategy) {
    return (draftState: OliEmbeddedModelSchema, _post: PostUndoable) => {
      OliEmbeddedActions.ensureAuthoringParts(draftState);

      const part = draftState.authoring.parts.find((p) => p.id === partId);
      if (part) {
        part.scoringStrategy = scoringStrategy;
      }
    };
  }

  static removeResourceURL(value: string) {
    return (draftState: OliEmbeddedModelSchema, post: PostUndoable) => {
      OliEmbeddedActions.ensureResourceURLs(draftState);

      const index = draftState.resourceURLs.findIndex((url) => url === value);
      const item = draftState.resourceURLs[index];
      post(
        makeUndoable('Removed a file', [Operations.insert('$.resourceURLs', clone(item), index)]),
      );

      draftState.resourceURLs = draftState.resourceURLs.filter((url) => url !== value);

      if (draftState.resourceVerification) {
        delete draftState.resourceVerification[lastPart(draftState.resourceBase, value)];
      }
    };
  }

  static replaceResourceVerification(resourceVerification: Record<string, 'verified' | 'missing'>) {
    return (draftState: OliEmbeddedModelSchema, _post: PostUndoable) => {
      draftState.resourceVerification = resourceVerification;
    };
  }
}
