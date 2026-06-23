import React from 'react';
import { WidgetProps } from '@rjsf/core';

const ImageAltTextWidget: React.FC<WidgetProps> = (props) => {
  const decorative = props.formContext?.formData?.custom?.decorative === true;
  const TextWidget = props.registry.widgets.TextWidget;
  const existingInputProps =
    typeof props.options.inputProps === 'object' &&
    props.options.inputProps !== null &&
    !Array.isArray(props.options.inputProps)
      ? props.options.inputProps
      : {};

  return (
    <TextWidget
      {...props}
      disabled={props.disabled || decorative}
      readonly={decorative}
      options={{
        ...props.options,
        inputProps: {
          ...existingInputProps,
          readOnly: decorative,
        },
      }}
    />
  );
};

export default ImageAltTextWidget;
