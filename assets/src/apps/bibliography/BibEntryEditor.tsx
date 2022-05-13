import * as React from 'react';
import { BibEntry } from 'data/content/bibentry';

const Cite = (window as any).cite;

export interface BibEntryEditorProps {
  bibEntry: BibEntry;
}

export const BibEntryEditor: React.FC<BibEntryEditorProps> = (props: BibEntryEditorProps) => {
  const bibOut = () => {
    const data = new Cite(props.bibEntry.content.data);
    return data.format('bibliography', {
      format: 'html',
      template: 'apa',
      lang: 'en-US',
    });
  };

  return <div dangerouslySetInnerHTML={{ __html: bibOut() }}></div>;
};
