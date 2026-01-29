import React, { useEffect, useRef, useState } from 'react';
import { render } from 'react-dom';
import ReactMonacoEditor, { IMonacoEditor } from '@uiw/react-monacoeditor';
import * as monaco from 'monaco-editor';
import { Maybe } from 'tsmonad';
import { registry } from 'components/monaco_lenses';
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
    const target = this.maybeGetAttribute('data-target');
    const setOptionsEvent = this.maybeGetAttribute('data-set-options');
    const setWidthHeightEvent = this.maybeGetAttribute('data-set-width-height');
    const setValueEvent = this.maybeGetAttribute('data-set-value');
    const getValueEvent = this.maybeGetAttribute('data-get-value');
    const useCodeLenses = this.maybeGetAttribute('data-use-code-lenses');
    const resizable = this.maybeGetAttribute('data-resizable');

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
      const [editor, setEditor] = useState<monaco.editor.IStandaloneCodeEditor | null>(null);
      const layoutTimeout = useRef<number | null>(null);
      const [options, setOptions] = useState(
        defaultOptions.caseOf({
          just: (o: any) => o,
          nothing: () => ({}),
        }),
      );

      const isResizable = resizable.valueOr(true);

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

      // Handle container resizing for Monaco editor
      useEffect(() => {
        if (!isResizable || !editor) return;

        const container = this.el;
        const resizeObserver = new ResizeObserver(() => {
          // Debounce resize to avoid excessive calls
          if (layoutTimeout.current) {
            window.clearTimeout(layoutTimeout.current);
          }
          layoutTimeout.current = window.setTimeout(() => {
            editor.layout();
          }, 100);
        });

        resizeObserver.observe(container);

        // Initial layout update to ensure proper sizing on mount
        layoutTimeout.current = window.setTimeout(() => {
          editor.layout();
        }, 100);

        return () => {
          resizeObserver.disconnect();
          if (layoutTimeout.current) {
            window.clearTimeout(layoutTimeout.current);
            layoutTimeout.current = null;
          }
        };
      }, [isResizable, editor]);

      const editorDidMount = (
        editor: monaco.editor.IStandaloneCodeEditor,
        monaco: IMonacoEditor,
      ) => {
        this.editor = editor;
        setEditor(editor);

        // configure the JSON language support with schemas and schema associations if
        // a schema uri is provided and schemas exist
        schemas.lift((schemas: any) => {
          monaco.languages.json.jsonDefaults.setDiagnosticsOptions({
            validate: true,
            schemas: schemas,
          });
        });

        useCodeLenses.lift((useCodeLenses: { name: string; context: any }[]) => {
          useCodeLenses.forEach(({ name, context }) => registry(name)(editor, monaco, context));
        });

        // Force layout update after a short delay to ensure proper sizing
        if (isResizable) {
          setTimeout(() => {
            editor.layout();
          }, 50);
        }

        this.maybePushEvent(onMountEvent);
      };

      const onChange = (value: string) => {
        // If both onChangeEvent and target are provided, create an event object with target
        // Otherwise, use the simple string event name
        const eventToSend = Maybe.all({ onChangeEvent, target }).caseOf({
          just: ({ onChangeEvent, target }) => Maybe.just({ name: onChangeEvent, target }),
          nothing: () => onChangeEvent,
        });

        this.maybePushEvent(eventToSend, value);
      };

      return (
        <ReactMonacoEditor
          width={isResizable ? '100%' : width}
          height={isResizable ? '100%' : height}
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
