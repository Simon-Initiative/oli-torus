import React from 'react';
import { RichText } from 'components/activities';
import { WriterContext, defaultWriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';

interface DeliveryElementRendererProps {
  element: RichText;
  context?: WriterContext;
  inline?: boolean;
}

/**
 * Renders an element specified on the client side. Intended to be used in combination
 * with ReactPhoenix and oli rendering logic for situations where it is more ideal to
 * render an element in the client space, such as highly interactive elements.
 *
 * Example:
 *
 *   def some_element(%Context{}, next, element) do
 *     {:safe, rendered} =
 *       ReactPhoenix.ClientSide.react_component("Components.DeliveryElementRenderer", %{
 *         "element" => element
 *       })
 *
 *     rendered
 *   end
 */
export const DeliveryElementRenderer: React.FC<DeliveryElementRendererProps> = ({
  element,
  context,
  inline,
}) => {
  const writerContext = defaultWriterContext(context);

  return (
    <HtmlContentModelRenderer
      inline={inline}
      content={element}
      context={writerContext}
      direction="auto"
    />
  );
};

DeliveryElementRenderer.defaultProps = {
  inline: false,
};
