import * as React from 'react';
import { BibEntry } from 'data/content/bibentry';
import { useEffect, useState } from 'react';
import { CitationModel, NameField } from './citationModel';
import { TextInput } from 'components/common/TextInput';
import { Select } from 'components/common/Selection';
import { camelizeKeys, cslSchema, ignoredAttributes, toFriendlyLabel } from './common';

// eslint-disable-next-line
// const cslSchema = require('./csl-data-schema.json');
export interface BibEntryEditorProps {
  citationModel: CitationModel;
  create: boolean;
  onEdit: (content: CitationModel) => void;
}

export const BibEntryEditor: React.FC<BibEntryEditorProps> = (props: BibEntryEditorProps) => {
  const [model, setModel] = useState<CitationModel>(props.citationModel);
  const [fields, setFields] = useState<string[]>(['title', 'issued']);

  const onEditString = (key: string, value: string) => {
    setModel({ ...model, [camelizeKeys(key)]: value });
    props.onEdit(model);
  };

  const renderStringEditor = (key: string, value: string) => {
    return (
      <TextInput
        editMode={true}
        width="100%"
        value={value}
        label=""
        type="string"
        onEdit={(value) => onEditString(key, value)}
      />
    );
  };

  const renderAuthorEditor = (key: string, value: NameField[]) => {
    // return (
    //   <TextInput
    //     editMode={true}
    //     width="100%"
    //     value={v}
    //     label=""
    //     type="string"
    //     onEdit={this.onEditAuthorEditor.bind(this, k)}
    //   />
    // );
  };

  const renderLabel = (key: string, value: any) => {
    // if (key === 'authorEditor') {
    //   return (
    //     <Select
    //       editMode={true}
    //       value={value.has('author') ? 'author' : 'editor'}
    //       onChange={(v) => this.onAuthorEditorSwitch(v)}
    //     >
    //       <option key="author" value="author">
    //         Author
    //       </option>
    //       <option key="editor" value="editor">
    //         Editor
    //       </option>
    //     </Select>
    //   );
    // }
    // if (key === 'volumeNumber') {
    //   let v = 'volume';
    //   value.lift((m) => (v = m.has('number') ? 'number' : 'volume'));
    //   return (
    // <Select editMode={true} value={v} onChange={(v) => this.onVolumeNumberSwitch(v)}>
    //   <option key="volume" value="volume">
    //     Volume
    //   </option>
    //   <option key="number" value="number">
    //     Number
    //   </option>
    // </Select>
    //   );
    // }
    return toFriendlyLabel(key);
  };

  const renderAttributeEditor = (key: string, value: any) => {
    if (value === undefined) {
      return null;
    }
    // if (key === 'authorEditor') {
    //   return this.renderAuthorEditor(key, value);
    // }
    // if (key === 'volumeNumber') {
    //   return this.renderVolumeNumber(key, value);
    // }
    if (typeof value === 'string') {
      return renderStringEditor(key, value);
    }
    // if (typeof value === 'object' && value.lift !== undefined) {
    //   return this.renderMaybeStringEditor(key, value);
    // }
  };

  const renderPair = (key1: string, value1: any, key2: string, value2: any) => {
    const labelStyle: React.CSSProperties = {
      width: '125px',
      textAlign: 'right',
      paddingRight: '5px',
    };

    return (
      <tr>
        <td style={labelStyle}>{renderLabel(key1, value1)}</td>
        <td>{renderAttributeEditor(key1, value1)}</td>
        <td style={labelStyle}>{renderLabel(key2, value2)}</td>
        <td>{renderAttributeEditor(key2, value2)}</td>
      </tr>
    );
  };

  const renderAttributeEditors = () => {
    const padded = fields.length % 2 === 1 ? [...fields, ''] : fields;

    const editors = [];
    for (let i = 0; i < padded.length / 2; i += 1) {
      const left = camelizeKeys(padded[i]);
      const right = camelizeKeys(padded[i + padded.length / 2]);
      let valLeft;
      let valRight;
      for (const [key, value] of Object.entries(model)) {
        if (key === left) {
          valLeft = value;
        }
        if (key === right) {
          valRight = value;
        }
      }
      if (!valLeft) valLeft = ' ';
      if (!valRight && right !== '') valRight = ' ';
      editors.push(renderPair(left, valLeft, right, valRight));
    }

    return editors;
  };

  const createEntryDropdown = () => {
    const attrs = Object.keys(cslSchema.items.properties).filter(
      (key: string) => !Object.keys(ignoredAttributes).find((el) => el === key),
    );
    return (
      <div className="form-inline">
        <div className="dropdown">
          <button
            type="button"
            id="createButton"
            className="btn btn-link dropdown-toggle btn-purpose"
            data-toggle="dropdown"
            aria-haspopup="true"
            aria-expanded="false"
          >
            Add Field
          </button>
          <div className="dropdown-menu" aria-labelledby="createButton">
            <div className="overflow-auto bg-light" style={{ maxHeight: '300px' }}>
              {attrs.map((e: string) => (
                <a
                  onClick={() => {
                    console.log('kekeek');
                    setFields([...fields, e]);
                  }}
                  className="dropdown-item"
                  href="#"
                  key={e}
                >
                  {toFriendlyLabel(e)}
                </a>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div>
      <div>{toFriendlyLabel(model.type).toUpperCase()}</div>
      <table style={{ width: '100%' }}>
        <tbody>{renderAttributeEditors()}</tbody>
      </table>
      {createEntryDropdown()}
    </div>
  );
};
