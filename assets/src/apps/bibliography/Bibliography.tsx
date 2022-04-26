import { BibEntry, Paging } from 'data/content/bibentry';
import React, { ChangeEvent, CSSProperties, useEffect, useState } from 'react';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import * as BibPersistence from 'data/persistence/bibentry';
// import * as Cite from 'citation-js';
// import { Cite } from 'citation-js';
// eslint-disable-next-line
const Cite = require('citation-js');

const store = configureStore();

const PAGE_SIZE = 5;

export interface BibliographyProps {
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
  totalCount: number;
}

const Bibliography: React.FC<BibliographyProps> = (props: BibliographyProps) => {
  const dispatch = useDispatch();
  const [value, setValue] = useState<string>('');
  const textAreaStyle: CSSProperties = {
    width: '100%',
  };

  useEffect(() => {
    fetchBibEntrys(defaultPaging());
  }, []);

  const fetchBibEntrys = (paging: Paging) => {
    BibPersistence.retrieve(props.projectSlug, paging).then((result) => {
      if (result.result === 'success') {
        console.log(JSON.stringify(result.queryResult.rows));
      }
    });
  };

  const handleOnChange = (event: ChangeEvent<HTMLTextAreaElement>) => {
    const changedVal = event.target.value;
    setValue(changedVal);
  };

  const handleSubmit = () => {
    if (value) {
      // console.log(Cite);
      const data = new Cite(value);
      console.log(
        data.get({
          format: 'string',
          type: 'json',
          style: 'csl',
          lang: 'en-US',
        }),
      );
      BibPersistence.create(props.projectSlug, 'the title', value);
    }
  };

  return (
    <div className="resource-editor row">
      <div className="col-12">
        <h1>Bibliography Editor</h1>
        <textarea style={textAreaStyle} rows={20} onChange={handleOnChange} value={value} />
        <button type="button" className="btn btn-danger" onClick={() => handleSubmit()}>
          Submit
        </button>
      </div>
    </div>
  );
};

function defaultPaging() {
  return { offset: 0, limit: PAGE_SIZE };
}

const BibliographyApp: React.FC<BibliographyProps> = (props) => (
  <Provider store={store}>
    <Bibliography {...props} />
  </Provider>
);

export default BibliographyApp;
