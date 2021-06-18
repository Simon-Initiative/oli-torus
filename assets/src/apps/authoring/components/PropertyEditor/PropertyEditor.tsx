/* eslint-disable react/prop-types */
import React from 'react';
import { Form } from 'react-bootstrap';

interface PropertyEditorProps {
  schema: any;
}

const PropertyEditor: React.FC<PropertyEditorProps> = ({ schema }) => {
  const inputs = Object.keys(schema).map((schemaKey) => {
    const {
      description,
      format,
      options,
      type,
      default: defaultValue,
    } = schema[schemaKey];

    const label = options?.label || schemaKey;

    return (
      <Form.Group key={schemaKey} controlId={`form_${schemaKey}`}>
        <Form.Label>{label}</Form.Label>
        <Form.Control type="text" placeholder={`Enter ${label}`} />
        {description ? <Form.Text className="text-muted">{description}</Form.Text> : null}
      </Form.Group>
    );
  });
  return <Form>{inputs}</Form>;
};
export default PropertyEditor;
