import { registerApplication } from './app';
import PageEditor from './page-editor/PageEditor';
import { globalStore } from 'state/store';

registerApplication('PageEditor', PageEditor, globalStore);
