import { Maybe } from 'tsmonad';
import { Identifiable } from 'data/content/model';
import {makeUndoable, PostUndoable} from "components/activities/types";
import {OliEmbeddedModelSchema} from "components/activities/oli_embedded/schema";
import {Operations} from "utils/pathOperations";
import {clone} from "utils/common";

export class OliEmbeddedActions {
  private static getById<T extends Identifiable>(slice: T[], id: string): Maybe<T> {
    return Maybe.maybe(slice.find((c) => c.id === id));
  }

  static editActivityXml(xml: string) {
    return (draftState: OliEmbeddedModelSchema, post: PostUndoable) => {
      draftState.modelXml = xml;
    };
  }

  static addResourceURL(value: string) {
    return (draftState: OliEmbeddedModelSchema, post: PostUndoable) => {
      if (draftState.resourceURLs.indexOf(value) === -1) {
        draftState.resourceURLs.push(value);
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
