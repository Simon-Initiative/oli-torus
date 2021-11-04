import { Maybe } from 'tsmonad';
import { Identifiable } from 'data/content/model';
import {PostUndoable} from "components/activities/types";
import {OliEmbeddedModelSchema} from "components/activities/oli_embedded/schema";

export class OliEmbeddedActions {
  private static getById<T extends Identifiable>(slice: T[], id: string): Maybe<T> {
    return Maybe.maybe(slice.find((c) => c.id === id));
  }

  static editActivityXml(xml: string) {
    return (draftState: OliEmbeddedModelSchema, post: PostUndoable) => {
      draftState.modelXml = xml;
    };
  }
}
