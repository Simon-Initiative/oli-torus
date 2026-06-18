import React from 'react';
import { WidgetProps } from '@rjsf/core';

const ImageAltTextWidget: React.FC<WidgetProps> = (props) => {
  const decorative = props.formContext?.formData?.custom?.decorative === true;
  const TextWidget = props.registry.widgets.TextWidget;

  return (
    <TextWidget
      {...props}
      disabled={props.disabled || decorative}
      readonly={decorative}
      options={{
        ...props.options,
        inputProps: {
          ...(props.options?.inputProps || {}),
          readOnly: decorative,
        },
      }}
    />
  );
};

export default ImageAltTextWidget;
