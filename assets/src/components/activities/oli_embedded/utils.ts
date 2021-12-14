import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { OliEmbeddedModelSchema } from './schema';
import { RichText, ScoringStrategy } from '../types';

export const defaultEmbeddedModel: () => OliEmbeddedModelSchema = () => {
  return {
    base: "oli_embedded",
    src: 'index.html',
    modelXml: '<?xml version="1.0" encoding="UTF-8"?>\n' +
      '<!DOCTYPE embed_activity PUBLIC "-//Carnegie Mellon University//DTD Embed 1.1//EN" "http://oli.cmu.edu/dtd/oli-embed-activity_1.0.dtd">\n' +
      '<embed_activity id="custom_side" width="670" height="300">\n' +
      '\t<title>Custom Activity</title>\n' +
      '\t<source>webcontent/custom_activity/customactivity.js</source>\n' +
      '\t<assets>\n' +
      '\t\t<asset name="layout">webcontent/custom_activity/layout.html</asset>\n' +
      '\t\t<asset name="controls">webcontent/custom_activity/controls.html</asset>\n' +
      '\t\t<asset name="styles">webcontent/custom_activity/styles.css</asset>\n' +
      '\t\t<asset name="questions">webcontent/custom_activity/questions.xml</asset>\n' +
      '\t</assets>\n' +
      '</embed_activity>',
    resourceBase: guid(),
    resourceURLs: [],
    stem: fromText(''),
    title: 'Embedded activity',
    authoring: {
      parts: [{
        id: guid(),
        scoringStrategy: ScoringStrategy.average,
        responses: [],
        hints: [],
      },{
        id: guid(),
        scoringStrategy: ScoringStrategy.average,
        responses: [],
        hints: [],
      }],
      previewText: '',
    },
  };
};

export function fromText(text: string): { id: string; content: RichText } {
  return {
    id: guid() + '',
    content: [
      ContentModel.create<ContentModel.Paragraph>({
        type: 'p',
        children: [{ text }],
        id: guid() + '',
      }),
    ],
  };
}

export function lastPart(path: string): string {
  if(path.includes('webcontent')){
    return path.substring(path.lastIndexOf('webcontent'));
  }
  return path.substring(path.lastIndexOf('/') + 1);
}