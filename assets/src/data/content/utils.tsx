import { StructuredContent } from './resource';

export function getContentDescription(content: StructuredContent) : JSX.Element {

  if (content.children.length > 1) {
    const first = content.children[0];

    switch (first.type) {
      case 'audio':
        return <i>Audio Clip</i>;
      case 'code':
        return <i>Code Block</i>;
      case 'img':
        return <i>Image</i>;
      case 'youtube':
        return <i>YouTube Video</i>;
      case 'table':
        return <i>Table</i>;
      case 'math':
        return <i>Math Expression</i>;
      case 'ol':
      case 'ul':
        return <i>List</i>;
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
      case 'p':
      case 'blockquote':
        let text = '';
        for (let i = 0; i < first.children.length && text.length < 30; i += 1) {
          text += first.children[i].text;
        }
        text = text.substr(0, 30);
        return <span>{text}</span>;
    }
  }

  return <i>Empty</i>;
}
