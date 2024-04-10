import LiveReact from 'phoenix_live_react';
import { AutoSelect } from './auto_select';
import { BeforeUnloadListener } from './before_unload';
import { CheckboxListener } from './checkbox_listener';
import { ClickOutside } from './click_outside';
import { CopyListener } from './copy_listener';
import { DateTimeLocalInputListener } from './datetimelocal_input_listener';
import { DragSource, DropTarget } from './dragdrop';
import { EmailList } from './email_list';
import { GraphNavigation } from './graph';
import { HideOnOutsideClick } from './hide_on_outside_click';
import { HierarchySelector } from './hierarchy_selector';
import { InputAutoSelect } from './input_auto_select';
import { KeepScrollAtBottom } from './keep_scroll_at_bottom';
import { LiveModal } from './live_modal';
import { LoadSurveyScripts } from './load_survey_scripts';
import { LtiConnectInstructions } from './lti_connect_instructions';
import { ModalLaunch } from './modal';
import { MonacoEditor } from './monaco_editor';
import { PointMarkers } from './point_markers';
import { ProjectsTypeahead } from './projects_typeahead';
import { ResizeListener } from './resize_listener';
import { ReviewActivity } from './review_activity';
import { Scroller } from './scroller';
import { SelectListener } from './select_listener';
import { SliderScroll } from './slider_scroll';
import { SubmitForm } from './submit_form';
import { SystemMessage } from './system_message';
import { TextInputListener } from './text_input_listener';
import { TextareaListener } from './textarea_listener';
import { ThemeToggle } from './theme_toggle';
import { TooltipInit, TooltipWithTarget } from './tooltip';
import { VideoPlayer } from './video_player';
import { PauseOthersOnSelected, VideoPreview } from './video_preview';

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
  TooltipWithTarget,
  BeforeUnloadListener,
  ThemeToggle,
  LtiConnectInstructions,
  HierarchySelector,
  TextareaListener,
  LiveReact,
  SubmitForm,
  LoadSurveyScripts,
  LiveModal,
  EmailList,
  ClickOutside,
  HideOnOutsideClick,
  Scroller,
  ResizeListener,
  KeepScrollAtBottom,
  SliderScroll,
  VideoPlayer,
  VideoPreview,
  PauseOthersOnSelected,
  PointMarkers,
  AutoSelect,
};
