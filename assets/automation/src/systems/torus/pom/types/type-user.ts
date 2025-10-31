export const TYPE_USER = {
  student: 'student',
  instructor: 'instructor',
  author: 'author',
  administrator: 'administrator',
} as const;

export type TypeUser = keyof typeof TYPE_USER;
