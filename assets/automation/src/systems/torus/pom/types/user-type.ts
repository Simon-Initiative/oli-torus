export const userType = ['student', 'instructor', 'author', 'administrator'] as const;
export type UserType = (typeof userType)[number];
export const USER_TYPES = {
  STUDENT: userType[0],
  INSTRUCTOR: userType[1],
  AUTHOR: userType[2],
  ADMIN: userType[3],
} as const;
