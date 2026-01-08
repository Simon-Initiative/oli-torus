import * as React from 'react';
import { BibEntry } from 'data/content/bibentry';
import { toCiteInput } from 'utils/bibliography';

const Cite = (window as any).cite;

export interface BibEntryViewProps {
  bibEntry: BibEntry;
}

export const BibEntryView: React.FC<BibEntryViewProps> = (props: BibEntryViewProps) => {
  const bibOut = () => {
    const data = new Cite(toCiteInput(props.bibEntry.content.data));
    return data.format('bibliography', {
      format: 'html',
      template: 'apa',
      lang: 'en-US',
      // include any note, used for URL in legacy bib entries
      append: (entry: any) => `${entry.note ? ' ' + entry.note : ''}`,
    });
  };

  return <div dangerouslySetInnerHTML={{ __html: bibOut() }}></div>;
};
