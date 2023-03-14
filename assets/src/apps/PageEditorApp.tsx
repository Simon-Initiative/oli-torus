import PageEditor from './page-editor/PageEditor';
import { registerApplication } from './app';
import { globalStore } from 'state/store';

registerApplication('PageEditor', PageEditor, globalStore);
