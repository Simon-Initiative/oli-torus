import { ReactEditor } from 'slate-react'


export type CommandDesc = {
  type: 'CommandDesc',
  icon: string,
  command: Command,
  description: string,
}

export type Command = {
  precondition: (editor: ReactEditor) => void,
  execute: (editor: ReactEditor) => void,
}