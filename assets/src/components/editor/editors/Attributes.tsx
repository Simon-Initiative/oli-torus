import * as ContentModel from 'data/content/model';

export type Attribute = {
  key: string,
  value: string,
};

export type AttributesProps = {
  attributes: Attribute[],
  onEdit: (attribute: Attribute) => void;
}

export const Attributes = (props: AttributesProps) => {
  const rows = props.attributes.map(a => {
    return (
      <tr>
        <td>{a.key}</td>
        <td>{a.value}</td>
      </tr>
    );
  })
  return (
    <table className="table table-sm">
      <tbody>
        {rows}
      </tbody>
    </table>
  );
}

export function getEditableAttributes(model: ContentModel.ModelElement) : Attribute[] {

  const ignoreKeys = {
    id: true,
    type: true,
    children: true,
  } as any;

  return Object.keys(model)
    .filter(k => ignoreKeys[k] === undefined)
    .map(k => ({ key: k, value: model[k] }));

}
