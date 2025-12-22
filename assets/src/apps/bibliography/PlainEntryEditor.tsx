import * as React from 'react';
import { ChangeEvent, useEffect, useState } from 'react';
import { BibEntry } from 'data/content/bibentry';
import { toCiteInput } from 'utils/bibliography';

const Cite = (window as any).cite;

export interface PlainEntryEditorProps {
  bibEntry?: BibEntry;
  onContentChange: (content: string, valid: boolean) => void;
}

export const PlainEntryEditor: React.FC<PlainEntryEditorProps> = (props: PlainEntryEditorProps) => {
  const [value, setValue] = useState<string>('');
  const [parseError, setParseError] = useState<string | null>(null);

  useEffect(() => {
    if (props.bibEntry) {
      try {
        const data = new Cite(toCiteInput(props.bibEntry?.content.data));

        const cslData = data.get({
          format: 'string',
          type: 'string',
          style: 'bibtex',
          lang: 'en-US',
        });
        setValue(cslData);
        props.onContentChange(cslData, true);
        setParseError(null);
      } catch (e) {
        // Show legacy/raw content and mark invalid until user fixes it
        const rawContent =
          typeof props.bibEntry?.content.data === 'string'
            ? props.bibEntry?.content.data
            : JSON.stringify(props.bibEntry?.content.data ?? '', null, 2);
        setValue(rawContent);
        setParseError('Could not parse existing entry; please fix the format before saving.');
        props.onContentChange(rawContent, false);
      }
    }
  }, []);

  const handleOnChange = (event: ChangeEvent<HTMLTextAreaElement>) => {
    const changedVal = event.target.value;
    setValue(changedVal);
    // Once the user edits, allow save if they have entered some content
    setParseError(null);
    props.onContentChange(changedVal, changedVal.trim().length > 0);
  };

  return (
    <div>
      {props.bibEntry ? null : (
        <>
          <div>
            Supports the following text formats @bibjson, @bibtex, @csl, @doi, @ris, @wikidata.
          </div>
          <div>
            For ISBN you may first use https://www.bibtex.com/c/isbn-to-bibtex-converter/ or any
            other online ISBN converter to transform ISBN entries into @bibtex then copy and paste
            the outcome of that convertion in the text area below
          </div>
        </>
      )}
      <textarea className="w-full bg-inherit" rows={20} onChange={handleOnChange} value={value} />
      {parseError ? <div className="text-danger mt-2">{parseError}</div> : null}
    </div>
  );
};
