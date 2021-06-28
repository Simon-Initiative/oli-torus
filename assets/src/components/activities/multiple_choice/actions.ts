import { MultipleChoiceModelSchema } from './schema';
import { fromText, makeResponse } from './utils';
import { RichText, Hint as HintType, Choice } from '../types';
import { Maybe } from 'tsmonad';
import { toSimpleText } from 'data/content/text';
import { Identifiable } from 'data/content/model';
import { PostUndoable, makeUndoable } from 'components/activities/types';
import { clone } from 'utils/common';

export class MCActions {
  private static getById<T extends Identifiable>(slice: T[], id: string): Maybe<T> {
    return Maybe.maybe(slice.find((c) => c.id === id));
  }
  private static getChoice = (draftState: MultipleChoiceModelSchema, id: string) =>
    MCActions.getById(draftState.choices, id);
  private static getResponse = (draftState: MultipleChoiceModelSchema, id: string) => {
    return MCActions.getById(draftState.authoring.parts[0].responses, id);
  };
  private static getHint = (draftState: MultipleChoiceModelSchema, id: string) =>
    MCActions.getById(draftState.authoring.parts[0].hints, id);

  static editStem(content: RichText) {
    return (draftState: MultipleChoiceModelSchema) => {
      draftState.stem.content = content;
      const previewText = toSimpleText({ children: content.model } as any);
      draftState.authoring.previewText = previewText;
    };
  }

  static addChoice() {
    return (draftState: MultipleChoiceModelSchema, post: PostUndoable) => {
      const newChoice: Choice = fromText('');
      draftState.choices.push(newChoice);
      draftState.authoring.parts[0].responses.push(
        makeResponse(`input like {${newChoice.id}}`, 0, ''),
      );
    };
  }

  static editChoice(id: string, content: RichText) {
    return (draftState: MultipleChoiceModelSchema, post: PostUndoable) => {
      MCActions.getChoice(draftState, id).lift((choice) => (choice.content = content));
    };
  }

  static removeChoice(id: string) {
    return (draftState: MultipleChoiceModelSchema, post: PostUndoable) => {

      const choiceIndex = draftState.choices.findIndex(c => c.id === id);
      const choice = draftState.choices[choiceIndex];
      const responseIndex = draftState.authoring.parts[0].responses.findIndex(
        (r) => r.rule === `input like {${id}}`,
      );
      const response = draftState.authoring.parts[0].responses[responseIndex];

      draftState.choices = draftState.choices.filter((c) => c.id !== id);
      draftState.authoring.parts[0].responses = draftState.authoring.parts[0].responses.filter(
        (r) => r.rule !== `input like {${id}}`,
      );

      const undoable = makeUndoable('Removed a choice', [
        { type: 'InsertOperation', path: '$.authoring.parts[0].responses', index: responseIndex, item: clone(response)},
        { type: 'InsertOperation', path: '$.choices', index: choiceIndex, item: clone(choice)}
      ])
      post(undoable);
    };
  }

  static editFeedback(id: string, content: RichText) {
    return (draftState: MultipleChoiceModelSchema, post: PostUndoable) => {
      MCActions.getResponse(draftState, id).lift((r) => (r.feedback.content = content));
    };
  }

  static addHint() {
    return (draftState: MultipleChoiceModelSchema, post: PostUndoable) => {
      const newHint: HintType = fromText('');
      // new hints are always cognitive hints. they should be inserted
      // right before the bottomOut hint at the end of the list
      const bottomOutIndex = draftState.authoring.parts[0].hints.length - 1;
      draftState.authoring.parts[0].hints.splice(bottomOutIndex, 0, newHint);
    };
  }

  static editHint(id: string, content: RichText) {
    return (draftState: MultipleChoiceModelSchema, post: PostUndoable) => {
      MCActions.getHint(draftState, id).lift((hint) => (hint.content = content));
    };
  }

  static removeHint(id: string, ) {
    return (draftState: MultipleChoiceModelSchema, post: PostUndoable) => {
      const hint = draftState.authoring.parts[0].hints.find((h) => h.id === id);
      const index = draftState.authoring.parts[0].hints.findIndex((h) => h.id === id);
      post(makeUndoable('Removed a hint',
        [{ type: 'InsertOperation', path: '$.authoring.parts[0].hints', index, item: clone(hint)}]));

      draftState.authoring.parts[0].hints = draftState.authoring.parts[0].hints.filter(
        (h) => h.id !== id,
      );

    };
  }
}
