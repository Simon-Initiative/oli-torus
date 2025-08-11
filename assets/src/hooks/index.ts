import LiveReact from 'phoenix_live_react';
import { AutoSelect } from './auto_select';
import { BeforeUnloadListener } from './before_unload';
import { CheckboxListener } from './checkbox_listener';
import { ClickOutside } from './click_outside';
import { ClickExecJS, HoverAway } from './click_variations';
import { ConditionalToggle } from './conditional_toggle';
import { CopyListener } from './copy_listener';
import { Countdown } from './countdown';
import { CountdownTimer } from './countdown_timer';
import { CustomFocusWrap } from './custom_focus_wrap';
import { DateTimeLocalInputListener } from './datetimelocal_input_listener';
import { DelayedSubmit } from './delayed_submit';
import { DisableSubmitted } from './disable_submitted';
import { DragSource, DropTarget } from './dragdrop';
import { EmailList } from './email_list';
import { EndDateTimer } from './end_date_timer';
import { DebouncedTextInputListener } from './debounced_text_input_listener';
import { EvaluateMathJaxExpressions } from './evaluate_mathjax_expressions';
import { ExpandContainers } from './expand_containers';
import { FixedNavigationBar } from './fixed_navigation_bar';
import { GraphNavigation } from './graph';
import { HierarchySelector } from './hierarchy_selector';
import { InputAutoSelect } from './input_auto_select';
import { KeepScrollAtBottom } from './keep_scroll_at_bottom';
import { LiveModal } from './live_modal';
import { LoadSurveyScripts } from './load_survey_scripts';
import { LtiConnectInstructions } from './lti_connect_instructions';
import { ModalLaunch } from './modal';
import { MonacoEditor } from './monaco_editor';
import { OnMountAndUpdate } from './on_mount_and_update';
import { FirePageTrigger } from './page_trigger';
import { PointMarkers } from './point_markers';
import { ProjectsTypeahead } from './projects_typeahead';
import { ReactToLiveView } from './react_to_liveview';
import { Recaptcha } from './recaptcha';
import { ResizeListener } from './resize_listener';
import { ReviewActivity } from './review_activity';
import { Scroller } from './scroller';
import { SelectListener } from './select_listener';
import { ShowTeaser } from './show_teaser';
import { SliderScroll } from './slider_scroll';
import { SubmitForm } from './submit_form';
import { SubmitTechSupportForm } from './submit_tech_support_form';
import { SystemMessage } from './system_message';
import { TextInputListener } from './text_input_listener';
import { TextareaListener } from './textarea_listener';
import { ThemeToggle } from './theme_toggle';
import { ToggleReadMore } from './toggle_read_more';
import { AutoHideTooltip, TooltipInit, TooltipWithTarget } from './tooltip';
import { VideoPlayer } from './video_player';
import { PauseOthersOnSelected, VideoPreview } from './video_preview';
import { WakeUpDot } from './wakeup_dot';

export const Hooks = {
  DebouncedTextInputListener,
  WakeUpDot,
  ExpandContainers,
  ShowTeaser,
  FirePageTrigger,
  DelayedSubmit,
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
  AutoHideTooltip,
  ClickExecJS,
  HoverAway,
  BeforeUnloadListener,
  ThemeToggle,
  LtiConnectInstructions,
  HierarchySelector,
  TextareaListener,
  ToggleReadMore,
  LiveReact,
  SubmitForm,
  LoadSurveyScripts,
  LiveModal,
  EmailList,
  ClickOutside,
  Scroller,
  ResizeListener,
  KeepScrollAtBottom,
  SliderScroll,
  VideoPlayer,
  VideoPreview,
  PauseOthersOnSelected,
  PointMarkers,
  AutoSelect,
  CustomFocusWrap,
  Countdown,
  CountdownTimer,
  EndDateTimer,
  EvaluateMathJaxExpressions,
  ReactToLiveView,
  DisableSubmitted,
  Recaptcha,
  OnMountAndUpdate,
  FixedNavigationBar,
  SubmitTechSupportForm,
  ConditionalToggle,
};
