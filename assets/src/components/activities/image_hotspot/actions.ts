import { PostUndoable } from 'components/activities/types';
import { Responses } from 'data/activities/model/responses';
import { matchListRule } from 'data/activities/model/rules';
import { Operations } from 'utils/pathOperations';
import { HasParts, makeContent } from '../types';
import * as ActivityTypes from '../types';

export const ImageHotspotActions = {
  setCoords(id: string, coords: number[]) {
    return (model: any, post: PostUndoable) => {
      const _content = makeContent(coords.join(',')).content;
      Operations.applyAll(model, [
        // Operations.replace(`$..choices[?(@.id=='${id}')].content`, content),
        Operations.replace(`$..choices[?(@.id=='${id}')].coords`, coords),
      ]);
    };
  },

  setImageURL(url: string) {
    return (model: any & HasParts, post: PostUndoable) => {
      model.imageURL = url;
    };
  },

  setSize(height: number, width: number) {
    return (model: any & HasParts, post: PostUndoable) => {
      model.height = height;
      model.width = width;
    };
  },

  setMultipleSelection(multiple: boolean) {
    return (model: any & HasParts, post: PostUndoable) => {
      model.multiple = multiple;

      // Changing type between CATA and MCQuestion requires changing response rules
      // For simplicity, just reset correct choice to default of choice 1
      const correctChoice = model.choices[0];
      if (multiple) {
        const correctResponse = ActivityTypes.makeResponse(
          matchListRule([correctChoice.id], [correctChoice.id]),
          1,
          '',
          true,
        );
        model.authoring.parts[0].responses = [correctResponse, Responses.catchAll()];
        model.authoring.correct = [[correctChoice.id], correctResponse.id];
      } else {
        model.authoring.parts[0].responses = Responses.forMultipleChoice(correctChoice.id);
      }
      // also clear any targeted feedback as it may reference now-replaced responses.
      model.authoring.targeted = [];
    };
  },
};
