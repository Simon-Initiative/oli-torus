import React, { useState } from 'react';
import { render } from 'react-dom';
import * as monaco from 'monaco-editor';
import ReactMonacoEditor from '@uiw/react-monacoeditor';
import { Maybe } from 'tsmonad';
import { getAttribute, maybeGetAttribute, maybePushEvent } from 'utils/surface';

export const MonacoEditor = {
  mounted() {
    // required
    const defaultValue = getAttribute(this, 'data-default-value');
    const language = getAttribute(this, 'data-language');

    // optional
    const defaultWidth = maybeGetAttribute(this, 'data-width');
    const defaultHeight = maybeGetAttribute(this, 'data-height');
    const defaultOptions = maybeGetAttribute(this, 'data-default-options');
    const dataSchemaUri = maybeGetAttribute(this, 'data-schema-uri');
    const dataSchemas = maybeGetAttribute(this, 'data-schemas');
    const onMountEvent = maybeGetAttribute(this, 'data-on-mount');
    const onChangeEvent = maybeGetAttribute(this, 'data-on-change');
    const setOptionsEvent = maybeGetAttribute(this, 'data-set-options');
    const setWidthHeightEvent = maybeGetAttribute(this, 'data-set-width-height');
    const setValueEvent = maybeGetAttribute(this, 'data-set-value');

    const schemas = Maybe.all({ dataSchemaUri, dataSchemas }).map(
      ({ dataSchemaUri, dataSchemas }) =>
        dataSchemas.map((s: any) => {
          if (s.uri === dataSchemaUri) {
            s.fileMatch = ['*'];
          }

          return s;
        }),
    );

    const LiveMonacoEditor = () => {
      const [width, setWidth] = useState(defaultWidth.valueOr(undefined));
      const [height, setHeight] = useState(defaultHeight.valueOr(undefined));
      const [value, setValue] = useState(defaultValue);
      const [options, setOptions] = useState(
        defaultOptions.caseOf({
          just: (o) => o,
          nothing: () => ({}),
        }),
      );

      // LiveView event handlers
      setOptionsEvent.lift((setOptionsEvent) =>
        this.handleEvent(setOptionsEvent, (newOptions: any) => setOptions(newOptions)),
      );

      setWidthHeightEvent.lift((setWidthHeightEvent) =>
        this.handleEvent(
          setWidthHeightEvent,
          ({ width, height }: { width?: string; height?: string }) => {
            Maybe.maybe(width).lift((w) => setWidth(w));
            Maybe.maybe(height).lift((h) => setHeight(h));
          },
        ),
      );

      setValueEvent.lift((setValueEvent) =>
        this.handleEvent(setValueEvent, ({ value }: any) => setValue(value)),
      );

      const editorDidMount = (editor: monaco.editor.IStandaloneCodeEditor) => {
        this.editor = editor;

        // configure the JSON language support with schemas and schema associations if
        // a schema uri is provided and schemas exist
        schemas.lift((schemas: any) => {
          monaco.languages.json.jsonDefaults.setDiagnosticsOptions({
            validate: true,
            schemas: schemas,
          });
        });

        maybePushEvent(this, onMountEvent);
      };

      const onChange = (value: string) => {
        maybePushEvent(this, onChangeEvent, value);
      };

      return (
        <ReactMonacoEditor
          width={width}
          height={height}
          value={value}
          language={language}
          options={options}
          editorDidMount={editorDidMount}
          onChange={onChange}
        />
      );
    };

    render(<LiveMonacoEditor />, this.el);
  },
  destroyed() {
    this.editor.dispose();
  },
};
