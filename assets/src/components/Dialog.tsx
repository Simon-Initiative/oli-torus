import React from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { PointMarkerContext, maybePointMarkerAttr } from 'data/content/utils';
import { WriterContext } from '../data/content/writers/context';
import { HtmlContentModelRenderer } from '../data/content/writers/renderer';

export const Speaker: React.FC<{ speaker?: ContentModel.DialogSpeaker; onClick?: () => void }> = ({
  speaker,
  onClick,
}) => {
  if (!speaker) {
    return (
      <div className="dialog-speaker" onClick={onClick}>
        Unknown Speaker
      </div>
    );
  }
  return (
    <div className="dialog-speaker" onClick={onClick}>
      {speaker?.image && <img src={speaker.image} className="img-fluid speaker-portrait" />}
      {speaker?.name && <div className="speaker-name">{speaker.name}</div>}
    </div>
  );
};

const DialogLine: React.FC<{
  speakers: ContentModel.DialogSpeaker[];
  context: WriterContext;
  line: ContentModel.DialogLine;
}> = ({ speakers, line, context }) => {
  const speakerIndex = speakers.findIndex((s) => s.id === line.speaker);
  const speakerClass = speakerIndex === -1 ? 'speaker-1' : `speaker-${speakerIndex + 1}`;
  return (
    <div className={`dialog-line ${speakerClass}`}>
      <Speaker speaker={speakers.find((s) => s.id === line.speaker)} />
      <div className="dialog-content">
        <HtmlContentModelRenderer context={context} content={line.children} />
      </div>
    </div>
  );
};

export const Dialog: React.FC<{
  dialog: ContentModel.Dialog;
  context: WriterContext;
  pointMarkerContext?: PointMarkerContext;
}> = ({ dialog, context, pointMarkerContext }) => {
  return (
    <div className="dialog" {...maybePointMarkerAttr(dialog, pointMarkerContext)}>
      {dialog.title && <h1>{dialog.title}</h1>}
      {dialog.lines.map((line, index) => (
        <DialogLine key={index} context={context} speakers={dialog.speakers} line={line} />
      ))}
    </div>
  );
};
