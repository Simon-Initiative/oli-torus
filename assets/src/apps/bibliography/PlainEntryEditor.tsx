import * as React from 'react';
import { BibEntry } from 'data/content/bibentry';
import { ChangeEvent, CSSProperties, useEffect, useState } from 'react';

const Cite = (window as any).cite;

export interface PlainEntryEditorProps {
  bibEntry?: BibEntry;
  onContentChange: (content: string) => void;
}

export const PlainEntryEditor: React.FC<PlainEntryEditorProps> = (props: PlainEntryEditorProps) => {
  const [value, setValue] = useState<string>('');

  const textAreaStyle: CSSProperties = {
    width: '100%',
  };

  useEffect(() => {
    if (props.bibEntry) {
      const data = new Cite(JSON.stringify(props.bibEntry?.content.data[0]));

      const cslData = data.get({
        format: 'string',
        type: 'string',
        style: 'bibtex',
        lang: 'en-US',
      });
      setValue(cslData);
    }
  }, []);

  const handleOnChange = (event: ChangeEvent<HTMLTextAreaElement>) => {
    const changedVal = event.target.value;
    setValue(changedVal);
    props.onContentChange(changedVal);
  };

  return (
    <div>
      <div>Supports the following text formats @bibjson, @bibtex, @csl, @doi, @ris, @wikidata.</div>
      <div>
        For ISBN you may first use https://www.bibtex.com/c/isbn-to-bibtex-converter/ or any other
        online ISBN converter to transform ISBN entries into @bibtex then copy and paste the outcome
        of that convertion in the text area below
      </div>
      <textarea style={textAreaStyle} rows={20} onChange={handleOnChange} value={value} />
    </div>
  );
};
