import React, { useEffect, useState } from 'react';
import { render } from 'react-dom';
import * as monaco from 'monaco-editor';
import ReactMonacoEditor from '@uiw/react-monacoeditor';
import { Maybe } from 'tsmonad';
import { surfaceHook } from 'utils/surface';

export const MonacoEditor = {
  mounted() {
    surfaceHook(this);

    // required
    const defaultValue = this.getAttribute('data-default-value');
    const language = this.getAttribute('data-language');

    // optional
    const defaultWidth = this.maybeGetAttribute('data-width');
    const defaultHeight = this.maybeGetAttribute('data-height');
    const defaultOptions = this.maybeGetAttribute('data-default-options');
    const dataSchemaUri = this.maybeGetAttribute('data-schema-uri');
    const dataSchemas = this.maybeGetAttribute('data-schemas');
    const onMountEvent = this.maybeGetAttribute('data-on-mount');
    const onChangeEvent = this.maybeGetAttribute('data-on-change');
    const setOptionsEvent = this.maybeGetAttribute('data-set-options');
    const setWidthHeightEvent = this.maybeGetAttribute('data-set-width-height');
    const setValueEvent = this.maybeGetAttribute('data-set-value');
    const getValueEvent = this.maybeGetAttribute('data-get-value');

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
      const [options, setOptions] = useState(
        defaultOptions.caseOf({
          just: (o: any) => o,
          nothing: () => ({}),
        }),
      );

      // LiveView event handlers
      useEffect(() => {
        this.maybeHandleEvent(setOptionsEvent, (options: any) => setOptions(options));

        this.maybeHandleEvent(
          setWidthHeightEvent,
          ({ width, height }: { width?: string; height?: string }) => {
            Maybe.maybe(width).lift((w) => setWidth(w));
            Maybe.maybe(height).lift((h) => setHeight(h));
          },
        );

        this.maybeHandleEvent(setValueEvent, ({ value }: any) =>
          this.editor.getModel().setValue(value),
        );

        this.maybeHandleEvent(getValueEvent, (meta: any) =>
          this.maybePushEvent(getValueEvent, { value: this.editor.getModel().getValue(), meta }),
        );
      }, []);

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

        this.maybePushEvent(onMountEvent);
      };

      const onChange = (value: string) => {
        this.maybePushEvent(onChangeEvent, value);
      };

      return (
        <ReactMonacoEditor
          width={width}
          height={height}
          value={defaultValue}
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
