import React from 'react';
import { AudioIcon } from './AudioIcon';
import { CarouselIcon } from './CarouselIcon';
import { CheckboxIcon } from './CheckboxIcon';
import { DropdownIcon } from './DropdownIcon';
import { HubSpokeIcon } from './HubSpokeIcon';
import { IframeIcon } from './IframeIcon';
import { ImageIcon } from './ImageIcon';
import { MultilineIcon } from './MultilineIcon';
import { NumberInputIcon } from './NumberInputIcon';
import { ParagraphIcon } from './ParagraphIcon';
import { PopupIcon } from './PopupIcon';
import { SliderIcon } from './SliderIcon';
import { TextInputIcon } from './TextInputIcon';
import { VideoIcon } from './VideoIcon';

export const toolbarIcons: Record<string, React.FC<{ fill?: string; stroke?: string }>> = {
  janus_text_flow: ParagraphIcon,
  janus_image: ImageIcon,
  janus_video: VideoIcon,
  janus_image_carousel: CarouselIcon,
  janus_popup: PopupIcon,
  janus_audio: AudioIcon,
  janus_capi_iframe: IframeIcon,
  janus_mcq: CheckboxIcon,
  janus_input_text: TextInputIcon,
  janus_dropdown: DropdownIcon,
  janus_input_number: NumberInputIcon,
  janus_slider: SliderIcon,
  janus_multi_line_text: MultilineIcon,
  janus_hub_spoke: HubSpokeIcon,
  janus_text_slider: SliderIcon,
};

export const toolbarTooltips: Record<string, string> = {
  janus_text_flow: 'Text block',
  janus_image: 'Image',
  janus_video: 'Video',
  janus_image_carousel: 'Image carousel',
  janus_popup: 'Popup',
  janus_audio: 'Audio',
  janus_capi_iframe: 'Iframe / Webpage',
  janus_mcq: 'Multiple choice question',
  janus_input_text: 'Text input',
  janus_dropdown: 'Dropdown',
  janus_input_number: 'Number input',
  janus_slider: 'Slider (Numeric)',
  janus_multi_line_text: 'Multiline text input',
  janus_hub_spoke: 'Hub and Spoke',
  janus_text_slider: 'Slider (Text)',
};
