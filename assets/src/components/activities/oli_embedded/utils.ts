import guid from 'utils/guid';
import { OliEmbeddedModelSchema } from './schema';
import { makeStem, ScoringStrategy } from '../types';

export const defaultEmbeddedModel: () => OliEmbeddedModelSchema = () => {
  return {
    base: 'embedded',
    src: 'index.html',
    modelXml: `<?xml version="1.0" encoding="UTF-8"?>
    <embed_activity id="custom_side" width="670" height="300">
        <title>Custom Activity</title>
        <source>webcontent/custom_activity/customactivity.js</source>
        <assets>
            <asset name="layout">webcontent/custom_activity/layout.html</asset>
            <asset name="controls">webcontent/custom_activity/controls.html</asset>
            <asset name="styles">webcontent/custom_activity/styles.css</asset>
            <asset name="questions">webcontent/custom_activity/questions.xml</asset>
        </assets>
    </embed_activity>`,
    resourceBase: guid(),
    resourceURLs: [],
    stem: makeStem(''),
    title: 'Embedded activity',
    authoring: {
      parts: [
        {
          id: guid(),
          scoringStrategy: ScoringStrategy.average,
          responses: [],
          hints: [],
        },
        {
          id: guid(),
          scoringStrategy: ScoringStrategy.average,
          responses: [],
          hints: [],
        },
      ],
      previewText: '',
    },
  };
};

export function lastPart(path: string): string {
  if (path.includes('webcontent')) {
    return path.substring(path.lastIndexOf('webcontent'));
  }
  return path.substring(path.lastIndexOf('/') + 1);
}
