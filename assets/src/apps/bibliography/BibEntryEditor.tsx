import * as React from 'react';
import * as Immutable from 'immutable';
import { useEffect, useState } from 'react';
import { CitationModel, DateField, isDateField, isNameField, NameField } from './citationModel';
import { TextInput } from 'components/common/TextInput';
import { cslSchema, ignoredAttributes, toFriendlyLabel } from './common';

export interface BibEntryEditorProps {
  citationModel: CitationModel;
  create: boolean;
  onEdit: (content: CitationModel) => void;
}

export const BibEntryEditor: React.FC<BibEntryEditorProps> = (props: BibEntryEditorProps) => {
  const [model, setModel] = useState<CitationModel>({ ...props.citationModel });
  const [allFields, setAllFields] = useState<Immutable.List<string>>(
    Immutable.List<string>(Object.keys(cslSchema.items.properties) as any),
  );

  useEffect(() => {}, []);

  const onEditString = (key: string, value: string) => {
    setModel({ ...model, [key]: value });
    props.onEdit({ ...model });
  };

  const onEditNameEditor = (index: number, key: string, key2: string, value: string) => {
    const updateModel = { ...model };
    const entry = Object.entries(updateModel).find(([k, _v]) => k === key);
    if (entry) {
      let val = entry[1][index];
      val = { ...val, [key2]: value };
      entry[1].splice(index, 1, val);
      setModel(updateModel);
      props.onEdit({ ...model });
    }
  };

  const onEditDateEditor = (index: number, key: string, key2: string, value: string) => {
    let updateModel = { ...model };
    const entry = Object.entries(updateModel).find(([k, _v]) => k === key);
    if (entry) {
      let val = entry[1];
      if (index > -1) {
        val = val[key2];
        val[0].splice(index, 1, value);
      } else {
        val = { ...val, [key2]: value };
        updateModel = { ...updateModel, [key]: val };
      }
      setModel(updateModel);
      props.onEdit({ ...model });
    }
  };

  const renderStringEditor = (key: string, value: string) => {
    return (
      <TextInput
        editMode={true}
        width="100%"
        value={value}
        label=""
        type="string"
        onEdit={(v) => onEditString(key, v)}
      />
    );
  };

  const renderDateEditor = (key: string, value: DateField) => {
    return (
      <div className="ml-4">
        {Object.entries(value).map((e) => (
          <div key={e[0]} className="form-row form-group">
            <label className="control-label" htmlFor={e[0]}>
              {renderLabel(e[0])}
            </label>
            <div className="col-sm-12">
              {e[0] === 'date-parts' ? (
                <div className="d-flex">
                  <div className="col-sm-4">
                    <TextInput
                      editMode={true}
                      width="100%"
                      value={e[1][0][0]}
                      label="Year"
                      type="string"
                      onEdit={(v) => {
                        onEditDateEditor(0, key, e[0], v);
                      }}
                    />
                  </div>
                  <div className="col-sm-4">
                    <TextInput
                      editMode={true}
                      width="100%"
                      value={e[1][0].length > 1 ? e[1][0][1] : ''}
                      label="Month"
                      type="string"
                      onEdit={(v) => {
                        onEditDateEditor(1, key, e[0], v);
                      }}
                    />
                  </div>
                  <div className="col-sm-4">
                    <TextInput
                      editMode={true}
                      width="100%"
                      value={e[1][0].length > 2 ? e[1][0][2] : ''}
                      label="Day"
                      type="string"
                      onEdit={(v) => {
                        onEditDateEditor(2, key, e[0], v);
                      }}
                    />
                  </div>
                </div>
              ) : (
                <TextInput
                  editMode={true}
                  width="100%"
                  value={e[1]}
                  label=""
                  type="string"
                  onEdit={(v) => {
                    onEditDateEditor(-1, key, e[0], v);
                  }}
                />
              )}
            </div>
          </div>
        ))}
      </div>
    );
  };

  const renderNameField = (index: number, key: string, value: NameField) => {
    return (
      <div className="d-flex">
        {Object.entries(value).map((e) => (
          <div key={e[0]} className="col-sm-6">
            <TextInput
              editMode={true}
              width="100%"
              value={e[1]}
              label={renderLabel(e[0])}
              type="string"
              onEdit={(v) => onEditNameEditor(index, key, e[0], v)}
            />
          </div>
        ))}
      </div>
    );
  };

  const renderNameEditor = (key: string, values: NameField[]) => {
    return (
      <div className="ml-4">
        {values.map((e, index) => (
          <div key={index} className="form-horizontal">
            {renderNameField(index, key, e)}
          </div>
        ))}
        <button
          type="button"
          className="btn btn-link"
          onClick={() => {
            setModel({ ...model, [key]: [...values, { given: '', family: '' }] });
          }}
        >
          <i className="las la-solid la-plus"></i> {'Add ' + toFriendlyLabel(key)}
        </button>
      </div>
    );
  };

  const renderLabel = (key: string) => {
    return toFriendlyLabel(key);
  };

  const renderAttributeEditor = (key: string, value: any) => {
    if (value === undefined) {
      return null;
    }
    if (typeof value === 'string') {
      return renderStringEditor(key, value);
    }

    if (isNameField(key)) {
      return renderNameEditor(key, value);
    }

    if (isDateField(key)) {
      return renderDateEditor(key, value);
    }
  };

  const initDefaultValue = (key: string) => {
    if (isNameField(key)) {
      return [{ given: '', family: '' }];
    }
    if (isDateField(key)) {
      const c = new Date();
      return { 'date-parts': [[c.getFullYear(), c.getMonth() + 1, c.getDate()]] };
    }
    return '';
  };

  const renderField = (key1: string, value1: any) => {
    return (
      <div className="form-row form-group">
        <label className="control-label" htmlFor={key1}>
          {renderLabel(key1)}
        </label>
        <div className="col-sm-12">{renderAttributeEditor(key1, value1)}</div>
      </div>
    );
  };

  const renderAttributeEditors = () => {
    const editors = [];

    for (const [key, value] of Object.entries(model)) {
      if (!Object.keys(ignoredAttributes).find((e) => e === key)) {
        editors.push(renderField(key, value));
      }
    }

    return editors;
  };

  const createEntryDropdown = () => {
    const attrs = allFields.filter(
      (key: string) =>
        !Object.keys(ignoredAttributes).find((el) => el === key) &&
        !Object.keys(model).find((el) => el === key),
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
                    setModel({ ...model, [e]: initDefaultValue(e) });
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
      <div className="text-info">{toFriendlyLabel(model.type).toUpperCase()}</div>
      <div className="overflow-auto form-horizontal p-3 bg-light" style={{ maxHeight: '400px' }}>
        {renderAttributeEditors()}
      </div>
      {createEntryDropdown()}
    </div>
  );
};
