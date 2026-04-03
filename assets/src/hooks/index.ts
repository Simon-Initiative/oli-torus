import LiveReact from 'phoenix_live_react';
import { AdaptiveDialogueSync } from './adaptive_dialogue_sync';
import { AdaptivePreviewPanel } from './adaptive_preview_panel';
import { AnnotationBubbles } from './annotation_bubbles';
import { AutoSelect } from './auto_select';
import { BeforeUnloadListener } from './before_unload';
import { CheckboxListener } from './checkbox_listener';
import { ChunkLogsDetails, ChunkLogsViewer } from './chunk_logs_viewer';
import { ClickOutside } from './click_outside';
import { ClickExecJS, HoverAway } from './click_variations';
import { ConditionalToggle } from './conditional_toggle';
import { ContainerToggleAriaLabel } from './container_toggle_aria_label';
import { CopyListener } from './copy_listener';
import { CopyToClipboard } from './copy_to_clipboard';
import { Countdown } from './countdown';
import { CountdownTimer } from './countdown_timer';
import { CustomFocusWrap } from './custom_focus_wrap';
import { DashboardSectionChrome } from './dashboard_section_chrome';
import { DateTimeLocalInputListener } from './datetimelocal_input_listener';
import { DebouncedTextInputListener } from './debounced_text_input_listener';
import { DelayedSubmit } from './delayed_submit';
import { DisableSubmitted } from './disable_submitted';
import { DragSource, DropTarget } from './dragdrop';
import { EmailList } from './email_list';
import { EndDateTimer } from './end_date_timer';
import { EvaluateMathJaxExpressions } from './evaluate_mathjax_expressions';
import { ExpandContainers } from './expand_containers';
import { FixedNavigationBar } from './fixed_navigation_bar';
import { GlobalTooltip } from './global_tooltip';
import { GraphNavigation } from './graph';
import { HierarchySelector } from './hierarchy_selector';
import { HighlightCode } from './highlight_code';
import { HomeMobileTabs } from './home_mobile_tabs';
import { IframeLoadState } from './iframe_load_state';
import { InputAutoSelect } from './input_auto_select';
import { KeepScrollAtBottom } from './keep_scroll_at_bottom';
import { ListNavigatorDropdown } from './list_navigator_dropdown';
import { LiveModal } from './live_modal';
import { LoadSurveyScripts } from './load_survey_scripts';
import { LtiConnectInstructions } from './lti_connect_instructions';
import { ManualGradingScoreInput } from './manual_grading_score_input';
import { ModalLaunch } from './modal';
import { MonacoEditor } from './monaco_editor';
import { OnMountAndUpdate } from './on_mount_and_update';
import { OverflowChipList } from './overflow_chip_list';
import { PageContentHooks } from './page_content_hooks';
import { FirePageTrigger } from './page_trigger';
import { PointMarkers } from './point_markers';
import { PreserveScrollAnchor } from './preserve_scroll_anchor';
import { ProgressTileChart } from './progress_tile_chart';
import { ProjectsTypeahead } from './projects_typeahead';
import { ReactToLiveView } from './react_to_liveview';
import { ReadMoreToggle } from './read_more_toggle';
import { Recaptcha } from './recaptcha';
import { ResizeListener } from './resize_listener';
import { ReviewActivity } from './review_activity';
import { SaveCookiePreferences } from './save_cookie_preferences';
import { ScrollToTheTop } from './scroll_to_the_top';
import { Scroller } from './scroller';
import { SelectListener } from './select_listener';
import { ShowTeaser } from './show_teaser';
import { SliderScroll } from './slider_scroll';
import { StickyTechSupportButton } from './sticky_tech_support_button';
import { StudentSupportChart } from './student_support_chart';
import { SubmitForm } from './submit_form';
import { SubmitTechSupportForm } from './submit_tech_support_form';
import { SyncChevronState } from './sync_chevron_state';
import { SystemMessage } from './system_message';
import { TagsComponent } from './tags_component';
import { TextInputListener } from './text_input_listener';
import { TextareaListener } from './textarea_listener';
import { ThemeToggle } from './theme_toggle';
import { AutoHideTooltip, Popover, TooltipInit, TooltipWithTarget } from './tooltip';
import { VideoPlayer } from './video_player';
import { PauseOthersOnSelected, VideoPreview } from './video_preview';
import { WakeUpDot } from './wakeup_dot';

export const Hooks = {
  AdaptivePreviewPanel,
  AdaptiveDialogueSync,
  AnnotationBubbles,
  DebouncedTextInputListener,
  GlobalTooltip,
  WakeUpDot,
  ExpandContainers,
  ShowTeaser,
  FirePageTrigger,
  DelayedSubmit,
  GraphNavigation,
  DropTarget,
  DragSource,
  HomeMobileTabs,
  ModalLaunch,
  InputAutoSelect,
  IframeLoadState,
  ProjectsTypeahead,
  ProgressTileChart,
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
  Popover,
  ClickExecJS,
  HoverAway,
  BeforeUnloadListener,
  ThemeToggle,
  LtiConnectInstructions,
  ManualGradingScoreInput,
  HierarchySelector,
  TextareaListener,
  LiveReact,
  SubmitForm,
  LoadSurveyScripts,
  LiveModal,
  ListNavigatorDropdown,
  EmailList,
  ClickOutside,
  ChunkLogsDetails,
  ChunkLogsViewer,
  Scroller,
  ResizeListener,
  KeepScrollAtBottom,
  SliderScroll,
  VideoPlayer,
  VideoPreview,
  PauseOthersOnSelected,
  PointMarkers,
  PreserveScrollAnchor,
  AutoSelect,
  CustomFocusWrap,
  Countdown,
  CountdownTimer,
  DashboardSectionChrome,
  EndDateTimer,
  EvaluateMathJaxExpressions,
  HighlightCode,
  PageContentHooks,
  ReactToLiveView,
  DisableSubmitted,
  Recaptcha,
  OnMountAndUpdate,
  OverflowChipList,
  FixedNavigationBar,
  SubmitTechSupportForm,
  StickyTechSupportButton,
  StudentSupportChart,
  SyncChevronState,
  ConditionalToggle,
  CopyToClipboard,
  ReadMoreToggle,
  TagsComponent,
  SaveCookiePreferences,
  ScrollToTheTop,
  ContainerToggleAriaLabel,
};
