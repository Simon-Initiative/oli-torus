import { globalStore } from 'state/store';
import { registerApplication } from './app';
import PageEditor from './page-editor/PageEditor';

registerApplication('PageEditor', PageEditor, globalStore);
