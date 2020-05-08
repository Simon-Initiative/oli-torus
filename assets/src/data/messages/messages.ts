import guid from 'utils/guid';

export enum Severity {
  Error = 'Error',
  Warning = 'Warning',
  Information = 'Information',
  Task = 'Task',
}

export enum Priority {
  Lowest,
  Low,
  Medium,
  High,
  Highest,
}

export type MessageAction = {
  label: string,
  enabled: boolean,
  execute: (message: Message) => void;
};

export type Message = {
  guid: string;
  severity: Severity;
  priority: Priority;
  content: JSX.Element | string;
  actions: MessageAction[];
  canUserDismiss: boolean;
};

export const createMessage = (params: Partial<Message> = {}) => ({
  guid: params.guid || guid(),
  severity: params.severity || Severity.Error,
  priority: params.priority || Priority.Medium,
  content: params.content || 'Default message',
  actions: params.actions || [],
  canUserDismiss: params.canUserDismiss || false,
});
