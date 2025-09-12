# Users and Organization

This document covers directives for creating and managing users, institutions, and enrollments.

## Table of Contents
- [user](#user) - Create users
- [institution](#institution) - Create institutions
- [enroll](#enroll) - Enroll users in sections
- [Complete Examples](#complete-examples)

---

## user

Creates users with different roles in the system.

### Parameters
- `name`: Internal identifier for the user (required)
- `type`: User type - `author`, `instructor`, or `student` (default: `student`)
- `email`: User email address (default: `{name}@test.edu`)
- `given_name`: User's first name (default: same as `name`)
- `family_name`: User's last name (default: "Test")

### User Types

#### Author
Can create and edit projects:
```yaml
- user:
    name: "course_author"
    type: author
    email: "author@university.edu"
    given_name: "Jane"
    family_name: "Smith"
```

#### Instructor
Can manage sections and view analytics:
```yaml
- user:
    name: "prof_jones"
    type: instructor
    email: "jones@college.edu"
    given_name: "Robert"
    family_name: "Jones"
```

#### Student
Can enroll in sections and complete coursework:
```yaml
- user:
    name: "alice"
    type: student
    email: "alice@student.edu"
    given_name: "Alice"
    family_name: "Anderson"
```

### Simple Examples
```yaml
# Minimal student (uses defaults)
- user:
    name: "bob"
    type: student

# Creates user with:
# - email: "bob@test.edu"
# - given_name: "bob"
# - family_name: "Test"
```

---

## institution

Creates an institution for organizing users and sections.

### Parameters
- `name`: Institution name (required)
- `country_code`: Two-letter country code (default: "US")
- `institution_email`: Admin email (default: `admin@{name}.edu`)
- `institution_url`: Institution website (default: `http://{name}.edu`)

### Examples

```yaml
# Simple institution
- institution:
    name: "State University"

# Detailed institution
- institution:
    name: "Technical College"
    country_code: "CA"
    institution_email: "admin@techcollege.ca"
    institution_url: "https://www.techcollege.ca"
```

---

## enroll

Enrolls users in sections with specific roles.

### Parameters
- `user`: Name of the user to enroll (required)
- `section`: Name of the section (required)
- `role`: Enrollment role - `student` or `instructor` (default: `student`)

### Examples

#### Student Enrollment
```yaml
# Create student
- user:
    name: "student1"
    type: student

# Enroll as student (default role)
- enroll:
    user: "student1"
    section: "math_101"
```

#### Instructor Enrollment
```yaml
# Create instructor
- user:
    name: "prof_smith"
    type: instructor

# Enroll as instructor
- enroll:
    user: "prof_smith"
    section: "math_101"
    role: instructor
```

#### Multiple Enrollments
```yaml
# One user in multiple sections
- enroll:
    user: "alice"
    section: "math_101"
    role: student

- enroll:
    user: "alice"
    section: "physics_201"
    role: student

# Multiple users in one section
- enroll:
    user: "student1"
    section: "chemistry_301"

- enroll:
    user: "student2"
    section: "chemistry_301"

- enroll:
    user: "prof_jones"
    section: "chemistry_301"
    role: instructor
```

---

## Complete Examples

### Example 1: Basic Class Setup

```yaml
# Create institution
- institution:
    name: "Community College"

# Create instructor
- user:
    name: "instructor1"
    type: instructor
    email: "instructor@community.edu"
    given_name: "Mary"
    family_name: "Johnson"

# Create students
- user:
    name: "john"
    type: student
    given_name: "John"
    family_name: "Doe"

- user:
    name: "jane"
    type: student
    given_name: "Jane"
    family_name: "Doe"

- user:
    name: "bob"
    type: student
    given_name: "Bob"
    family_name: "Smith"

# Create course project
- project:
    name: "intro_programming"
    title: "Introduction to Programming"
    root:
      children:
        - page: "Welcome"
        - container: "Module 1"

# Create section
- section:
    name: "prog_101_fall"
    title: "Programming 101 - Fall 2024"
    from: "intro_programming"

# Enroll instructor
- enroll:
    user: "instructor1"
    section: "prog_101_fall"
    role: instructor

# Enroll students
- enroll:
    user: "john"
    section: "prog_101_fall"
    role: student

- enroll:
    user: "jane"
    section: "prog_101_fall"
    role: student

- enroll:
    user: "bob"
    section: "prog_101_fall"
    role: student
```

### Example 2: Multiple Sections with Shared Instructor

```yaml
# Create users
- user:
    name: "prof_williams"
    type: instructor
    email: "williams@university.edu"

- user:
    name: "alice"
    type: student
- user:
    name: "bob"
    type: student
- user:
    name: "charlie"
    type: student
- user:
    name: "diana"
    type: student

# Create course
- project:
    name: "calculus"
    title: "Calculus I"
    root:
      children:
        - page: "Introduction"

# Create multiple sections
- section:
    name: "calc_morning"
    title: "Calculus I - Morning Section"
    from: "calculus"

- section:
    name: "calc_afternoon"
    title: "Calculus I - Afternoon Section"
    from: "calculus"

# Instructor teaches both sections
- enroll:
    user: "prof_williams"
    section: "calc_morning"
    role: instructor

- enroll:
    user: "prof_williams"
    section: "calc_afternoon"
    role: instructor

# Different students in each section
- enroll:
    user: "alice"
    section: "calc_morning"
- enroll:
    user: "bob"
    section: "calc_morning"

- enroll:
    user: "charlie"
    section: "calc_afternoon"
- enroll:
    user: "diana"
    section: "calc_afternoon"
```

### Example 3: Complete School Simulation

```yaml
# Create institution
- institution:
    name: "Tech Institute"
    country_code: "US"
    institution_email: "admin@techinst.edu"
    institution_url: "https://www.techinst.edu"

# Create faculty
- user:
    name: "dean"
    type: author
    email: "dean@techinst.edu"
    given_name: "Richard"
    family_name: "Dean"

- user:
    name: "prof_cs"
    type: instructor
    email: "cs@techinst.edu"
    given_name: "Computer"
    family_name: "Science"

- user:
    name: "prof_math"
    type: instructor
    email: "math@techinst.edu"
    given_name: "Mathematics"
    family_name: "Professor"

# Create diverse student body
- user:
    name: "freshman1"
    type: student
    email: "fresh1@student.techinst.edu"
    given_name: "Fresh"
    family_name: "One"

- user:
    name: "freshman2"
    type: student
    email: "fresh2@student.techinst.edu"
    given_name: "Fresh"
    family_name: "Two"

- user:
    name: "senior1"
    type: student
    email: "senior1@student.techinst.edu"
    given_name: "Senior"
    family_name: "One"

# Create courses
- project:
    name: "cs101"
    title: "Computer Science 101"
    root:
      children:
        - page: "Syllabus"
        - container: "Programming Basics"

- project:
    name: "math201"
    title: "Mathematics 201"
    root:
      children:
        - page: "Course Overview"
        - container: "Calculus"

# Create sections
- section:
    name: "cs101_fall"
    title: "CS 101 - Fall 2024"
    from: "cs101"

- section:
    name: "math201_fall"
    title: "Math 201 - Fall 2024"
    from: "math201"

# Assign instructors
- enroll:
    user: "prof_cs"
    section: "cs101_fall"
    role: instructor

- enroll:
    user: "prof_math"
    section: "math201_fall"
    role: instructor

# Freshmen take CS 101
- enroll:
    user: "freshman1"
    section: "cs101_fall"

- enroll:
    user: "freshman2"
    section: "cs101_fall"

# Senior takes Math 201
- enroll:
    user: "senior1"
    section: "math201_fall"

# Senior also audits CS 101
- enroll:
    user: "senior1"
    section: "cs101_fall"
```

### Example 4: Testing User Permissions

```yaml
# Create different user types
- user:
    name: "author_only"
    type: author

- user:
    name: "instructor_only"
    type: instructor

- user:
    name: "student_only"
    type: student

# Author creates content
- project:
    name: "authored_course"
    title: "Authored Course"
    root:
      children:
        - page: "Content"

# Create section
- section:
    name: "test_section"
    from: "authored_course"

# Test different enrollment combinations
- enroll:
    user: "instructor_only"
    section: "test_section"
    role: instructor

- enroll:
    user: "student_only"
    section: "test_section"
    role: student

# Authors typically don't enroll in sections
# They work on projects instead
```

## Notes

- User names must be unique within a test scenario
- The `type` field determines user capabilities in the system
- Email addresses should be unique (defaults ensure this)
- Authors are automatically set as the current author for subsequent project operations
- Institutions are optional but provide organizational structure
- Users can be enrolled in multiple sections
- Sections can have multiple instructors and students
- The default institution and author are created automatically if not specified