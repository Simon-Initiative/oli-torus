import LiveReact from 'phoenix_live_react';
import { BeforeUnloadListener } from './before_unload';
import { CheckboxListener } from './checkbox_listener';
import { CopyListener } from './copy_listener';
import { DateTimeLocalInputListener } from './datetimelocal_input_listener';
import { DragSource, DropTarget } from './dragdrop';
import { EmailList } from './email_list';
import { GraphNavigation } from './graph';
import { HierarchySelector } from './hierarchy_selector';
import { InputAutoSelect } from './input_auto_select';
import { LiveModal } from './live_modal';
import { LoadSurveyScripts } from './load_survey_scripts';
import { LtiConnectInstructions } from './lti_connect_instructions';
import { ModalLaunch } from './modal';
import { MonacoEditor } from './monaco_editor';
import { ProjectsTypeahead } from './projects_typeahead';
import { ReviewActivity } from './review_activity';
import { SelectListener } from './select_listener';
import { SubmitForm } from './submit_form';
import { SystemMessage } from './system_message';
import { TextInputListener } from './text_input_listener';
import { TextareaListener } from './textarea_listener';
import { ThemeToggle } from './theme_toggle';
import { TooltipInit } from './tooltip';

export const Hooks = {
  GraphNavigation,
  DropTarget,
  DragSource,
  ModalLaunch,
  InputAutoSelect,
  ProjectsTypeahead,
  TextInputListener,
  ReviewActivity,
  CheckboxListener,
  SelectListener,
  DateTimeLocalInputListener,
  CopyListener,
  SystemMessage,
  MonacoEditor,
  TooltipInit,
  BeforeUnloadListener,
  ThemeToggle,
  LtiConnectInstructions,
  HierarchySelector,
  TextareaListener,
  LiveReact,
  SubmitForm,
  LoadSurveyScripts,
  LiveModal,
  EmailList
};
