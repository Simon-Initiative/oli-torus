import { editor } from 'monaco-editor';
import { IMonacoEditor } from '@uiw/react-monacoeditor';

export interface ActivityLinksLensArgs {
  projectSlug: string;
}

export function activityLinksLens(
  editor: editor.IStandaloneCodeEditor,
  monaco: IMonacoEditor,
  { projectSlug }: ActivityLinksLensArgs,
) {
  monaco.languages.registerCodeLensProvider('json', {
    provideCodeLenses: function (model: any, token: any) {
      const value = model.getValue() as string;
      const lines = value.split('\n');

      const lenses = lines.reduce((acc, line: string, lineNumber: number) => {
        const activityIdRegex = /"activity_id":\s*(\d+)/;

        if (activityIdRegex.test(line)) {
          const [_match, activityId] = activityIdRegex.exec(line) as RegExpExecArray;

          const commandId = editor.addCommand(
            0,
            function () {
              window.open(`/project/${projectSlug}/history/resource_id/${activityId}`, '_blank');
            },
            '',
          ) as string;

          return [
            ...acc,
            {
              range: {
                startLineNumber: lineNumber + 1,
                startColumn: 1,
                endLineNumber: lineNumber + 1,
                endColumn: 1,
              },
              id: `Activity Ref ${lineNumber}`,
              command: {
                id: commandId,
                title: 'Open Activity Revision History',
              },
            },
          ];
        }

        return acc;
      }, []);

      return {
        lenses,
        dispose: () => {},
      };
    },
    resolveCodeLens: function (model: any, codeLens: any, token: any) {
      return codeLens;
    },
  });
}
