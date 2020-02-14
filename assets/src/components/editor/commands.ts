import { Editor, Transforms, createEditor, Text, Node } from 'slate';
import { Mark } from 'data/content/model';

export function isMarkActive(editor: Editor, mark: Mark): boolean {
    const [match] = Editor.nodes(editor, {
        match: n => n[mark] === true,
        universal: true,
    });

    return !!match;
}

export function toggleMark(editor: Editor, mark: Mark) {
    const isActive = isMarkActive(editor, mark)
    Transforms.setNodes(
        editor,
        { [mark]: isActive ? null : true },
        { match: n => Text.isText(n), split: true }
    );
}

