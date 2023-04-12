import { BibEntry } from 'data/content/bibentry';
import * as React from 'react';

const Cite = (window as any).cite;

export interface BibEntryViewProps {
  bibEntry: BibEntry;
}

export const BibEntryView: React.FC<BibEntryViewProps> = (props: BibEntryViewProps) => {
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
