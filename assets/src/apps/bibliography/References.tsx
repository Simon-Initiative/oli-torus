import { BibEntryView } from './BibEntryView';
import { BibEntry } from 'data/content/bibentry';
import * as Immutable from 'immutable';
import React, { useState } from 'react';

export interface ReferencesProps {
  bibReferences: BibEntry[];
}

export const References: React.FC<ReferencesProps> = (props: ReferencesProps) => {
  const [bibEntrys] = useState<Immutable.OrderedMap<string, BibEntry>>(
    Immutable.OrderedMap<string, BibEntry>(props.bibReferences.map((b) => [b.slug, b])),
  );

  const createBibEntryEditors = () => {
    return bibEntrys.toArray().map((item) => {
      const [key, bibEntry] = item;
      return (
        <div key={key} className="d-flex justify-content-start mb-4 small" id={bibEntry.slug}>
          {bibEntry.ordinal && <div className="mr-2">{bibEntry.ordinal}</div>}
          <BibEntryView key={key} bibEntry={bibEntry} />
        </div>
      );
    });
  };

  const references = createBibEntryEditors();

  return (
    <div>
      {!bibEntrys.isEmpty() && (
        <>
          <h6>References</h6>
          <div>{references}</div>
        </>
      )}
    </div>
  );
};
