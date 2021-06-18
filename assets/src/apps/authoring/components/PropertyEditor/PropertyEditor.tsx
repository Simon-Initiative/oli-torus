/* eslint-disable react/prop-types */
import React from 'react';
import { Form } from 'react-bootstrap';

interface SchemaOptions {
  label?: string;
  input_width?: string | number;
}
interface Schema {
  type: string;
  description?: string;
  format?: string;
  options: SchemaOptions;
  default?: any;
  properties?: Record<string, Schema>;
  items?: Schema;
}
interface PropertyEditorProps {
  schema: Schema;
}

const PropertyEditor: React.FC<PropertyEditorProps> = ({ schema }) => {
  const rootProps = schema.properties || {};
  // for now just using properties, but going to need to make a recursive schema renderer
  const inputs = Object.keys(rootProps).map((schemaKey) => {
    const { description, format, options, type, default: defaultValue } = rootProps[schemaKey];

    const label = options?.label || schemaKey;

    // TODO: base different editors off of type
    let controlType = 'text';
    if (type === 'string') {
      if (format === 'email') {
        controlType = 'email';
      }
    }
    if (type === 'number') {
      controlType = 'number';
    }
    if (type === 'boolean') {
      // render checkbox instead
    }

    return (
      <Form.Group key={schemaKey} controlId={`form_${schemaKey}`}>
        <Form.Label>{label}</Form.Label>
        <Form.Control type={controlType} placeholder={`Enter ${label}`} />
        {description ? <Form.Text className="text-muted">{description}</Form.Text> : null}
      </Form.Group>
    );
  });
  return <Form>{inputs}</Form>;
};
export default PropertyEditor;
