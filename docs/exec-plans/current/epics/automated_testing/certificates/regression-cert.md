Group,Test Case,Case,Stps to reproduce,Role ,User,Environment,Expected result,Result,Execution date,Tester executing,Bug ID,Case designer
CERT SET UP,A,Enable certificate,"1. Sign in as an author and choose a project
2. In the Overview screen, scroll down to ""Notes"" and click ""Enable Notes for all pages in the course""
3. Navigate to Create -> Curriculum
4. Under ""Create a page"", click ""Scored"" next to ""Basic"" (you can optionally skip this step and the next if there is already a scored page in the project you can use for the certificate)
5. Click ""Edit Page"" for the new page, then click the plus sign and then ""Input""
6. Add several more input items
7. Navigate to Publish -> Templates
8. Click into a template (or create one)
9. Scroll down to ""Certificate Settings"" and click ""Manage Certificate Settings""
10. Check Enable certificate capabilities for this template",Author,,,"1. Certificates are disabled by default
2. Certificate config including the ""Thresholds"", ""Design"", and ""Credentials Issued"" tabs appear when certificates enabled",To Do,,,,Amanda Buddemeyer
CERT SET UP,B,Configure thresholds,"1. Sign in as an author and choose a project with at least one template, at least one scored page, and with notes enabled
2. Navigate to Publish -> Templates
3. Click into a template
4. Scroll down to ""Certificate Settings"" and click ""Manage Certificate Settings""
5. Under ""Thresholds"", leave ""Required Discussion Posts"" at 0
6. Under ""Thresholds"", set ""Required Class Notes"" to 1
7. Under ""Thresholds"", set ""To earn a Certificate of Completion, students must score a minimum of"" to 50.0
8. Under ""Thresholds"", set ""To earn a Certificate with Distinction, students must score a minimum of"" to 75.0
9. Under ""Thresholds"" set ""On the following scored pages"" to one scored page
10. Under ""Thresholds"", check ""Require instructor approval""
11. Click ""Save Thresholds""",Author,,,"Flash message at the top of the screen that says ""Certificate settings saved successfully""",To Do,,,,Amanda Buddemeyer
CERT SET UP,C,Configure design titles,"1. Sign in as an author and choose a project with a certificate
2. Navigate to Publish -> Templates
3. Click into a template
4. Scroll down to ""Certificate Settings"" and click ""Manage Certificate Settings""
5. Under ""Design"", set a Course Title and Subtitle
6. Click ""Save Design""",Author,,,A preview should appear showing all of the correct design elements that were just configured,To Do,,,,Amanda Buddemeyer
CERT SET UP,D,Configure design admins,"1. Sign in as an author and choose a project with a certificate
2. Navigate to Publish -> Templates
3. Click into a template
4. Scroll down to ""Certificate Settings"" and click ""Manage Certificate Settings""
5. Under ""Design"", input three administrator names and titles
6. Click ""Save Design""",Author,,,A preview should appear showing all of the correct design elements that were just configured,To Do,,,,Amanda Buddemeyer
CERT SET UP,E,Configure design logo,"1. Sign in as an author and choose a project with a certificate
2. Navigate to Publish -> Templates
3. Click into a template
4. Scroll down to ""Certificate Settings"" and click ""Manage Certificate Settings""
5. Under ""Design"", upload a logo
6. Click ""Save Design""",Author,,,A preview should appear showing all of the correct design elements that were just configured,To Do,,,,Amanda Buddemeyer
CERT SET UP,F,Create cert section,"1. Sign in as an instructor who can make course sections
2. Click ""Create New Section""
3. Search for and select a template with a certificate configured
4. Give the section a name and number and click ""Next Step""
5. Give the course start and end dates and a meeting time and click ""Create Section""
6. On the ""Manage"" page, scroll down to ""Notes"" and enable notes
7. On the ""Manage"" page, scroll down to Certificate Settings and click ""Manage Certificate Settings""",Instructor,,,The certificate settings displayed in all three tabs should match the settings configured in the template,To Do,,,,Amanda Buddemeyer
CERT PROGRESS,A,View certificate default,"1. As a student, enroll in a course section with a certificate
2. Sign in as the student and click into the course
3. Scroll down to find the Course Progress widget",Student,,,"The Course Progress widget shows that there is a certificate that has discussion, notes, and assignment requirements, not of which have been completed",To Do,,,,Amanda Buddemeyer
CERT PROGRESS,B,Notes requirement,"1. As a student, enroll in a course section with a certificate that requires instructor approval and that has note requirements and has notes enabled
2. Sign in as the student and click into the course
3. Scroll down to the Course Progress widget and note the certificate progress
4. Click into a lesson or practice page
5. Click on the Notes toolbar on the far right side of the screen to open it and then select ""Class Notes""
6. Just to the right of the course content, click the plus icon to add a note.  Add as many notes as are required for the certificate
7. Navigate back to the section home page and scroll down to the Course Progress widget",Student,,,"1. The notes requirement should be unmet before adding notes
2. After adding notes, the content of the Course Progress widget should be show that the notes requirement has been completed and all other requirements are unchanged",To Do,,,,Amanda Buddemeyer
CERT PROGRESS,C,Assignment not good enough,"1. As a student, enroll in a course section with a certificate that requires instructor approval and that has note requirements and has notes enabled
2. Sign in as the student and click into the course
3. Scroll down to the Course Progress widget and note the certificate progress
4. Click into any assignments required for the certificate
5. For each one, complete the assignment but do poorly enough that a certificate will not be earned
6. Navigate back to the section home page and scroll down to the Course Progress widget",Student,,,"1. The assignments requirement should be unmet before doing the assignment(s)
2. The assignments requirements should still be unmet after doing the assignment(s)",To Do,,,,Amanda Buddemeyer
CERT PROGRESS,D,Pending certificate,"1. As a student, enroll in a course section with a certificate that requires instructor approval
2. Sign in as the student and click into the course
3. Scroll down to the Course Progress widget and note the certificate progress
4. Click into any assignments required for the certificate
5. For each one, complete the assignment well enough to earn the certificate but NOT the distinction
6. Navigate back to the section home page and scroll down to the Course Progress widget",Student,,,"1. The assignments requirement should be unmet before doing the assignment(s)
2. The assignments requirements should be met after doing the assignment(s)
3. The widget should indicate that the certificate is pending instructor approval
4. The instructor for the course should receive an email indicating that there is a student's certfiicate is pending",To Do,,,,Amanda Buddemeyer
CERT PROGRESS,E,Instructor view pending cert,"1. Sign in as an instructor
2. From an instructor email (for the same instructor) indicating that a student's certificate is pending, click "" View pending credentials""",Instructor,,,View the Overview -> Students page of the instructor interface showing the student's certificate as pending approval or denial,To Do,,,,Amanda Buddemeyer
CERT PROGRESS,F,Instructor consider deny,"1. Sign in as an instructor who has at least one student with a certificate pending
2. Click into a course with a pending certificate
3. Navigate to Overview -> Student
4. Click ""Deny"" for a student with a pending certificate",Instructor,,,A sample email should appear explaining that the certificate has been denied,To Do,,,,Amanda Buddemeyer
CERT PROGRESS,G,Instructor approval,"1. Sign in as an instructor who has at least one student with a certificate pending
2. Click into a course with a pending certificate
3. Navigate to Overview -> Student
4. Click ""Approve"" for a student with a pending certificate
5. Click ""Send Email""",Instructor,,,"1. The certificate status for the student should update to ""Approved""
2. The student should receive a notification email",To Do,,,,Amanda Buddemeyer
CERT PROGRESS,H,Earned certificate,"1. From a student certificate approval email, click link to see certificate
2. Sign in as the student who received the email
3. On the home page, scroll down to the Course Progress widget",Student,,,"1. The Course Progress widget should indicate that the certificate has been earned
2. Student should have certificate but NOT distinction",To Do,,,,Amanda Buddemeyer
CERT PROGRESS,I,View certificate,"1. From a student certificate approval email, click """"
2. Sign in as the student who received the email
3. On the home page, scroll down to the Course Progress widget
4. Click ""Access my certificate""
",Student,,,"1. View the certificate, all details as configured in the template.  
2. The student's name is correct",To Do,,,,Amanda Buddemeyer
CERT PROGRESS,J,Download certificate,"1. From a student certificate approval email, click """"
2. Sign in as the student who received the email
3. On the home page, scroll down to the Course Progress widget
4. Click ""Access my certificate""
5. Click ""Download""",Student,,,A PDF should download that has all of the correct certificate information and setup,To Do,,,,Amanda Buddemeyer
CERT PROGRESS,K,Earned distinction,"1. As a student, enroll in a course section with a certificate that requires instructor approval
2. Sign in as the student and click into the course
3. Scroll down to the Course Progress widget and note the certificate progress
4. Click into any assignments required for the certificate
5. For each one, complete the assignment well enough to earn a distinction
6. Navigate back to the section home page and scroll down to the Course Progress widget
7. Click ""Access my certificate""",Student,,,"1. The notification email should indicate that the certificate has a distinction
2. The certificate should have all of the correct information and also indicate that a distinction was earned",To Do,,,,Amanda Buddemeyer
CERT UPDATE,A,Add pages,"1. Sign in as an instructor who can make course sections
2. Click into a course with certificate requirements
3. In the ""Manage"" tab, scroll down to and click ""Customize Content""
4. Click ""Add Materials""
5. Find and add one scored page and one unscored page
6. Log out and log in as a new student for this course section
7. Complete the certificate requirements for the course",Instructor / Student,,,The certificate requirements should be unchanged and not include the new pages,To Do,,,,Amanda Buddemeyer
CERT UPDATE,B,Make update,"1. Sign in as an author and choose a project with at least one template with a certificate requirement and at least one course section made from that template
2. Navigate to Publish -> Templates
3. Click into a template with certificate requirements
4. Scroll down to ""Certificate Settings"" and click ""Manage Certificate Settings""
5. Under ""Thresholds"", change ""To earn a Certificate of Completion, students must score a minimum of"" to a different value
6. Under ""Thresholds, add or remove a scored page to/from the ""On the following scored pages"" field
7. Click ""Save Thresholds""",Author,,,"Flash message at the top of the screen that says ""Certificate settings saved successfully""",To Do,,,,Amanda Buddemeyer
CERT UPDATE,C,Update for new section,"1. Sign in as an instructor with authorization to create course sections
2. Create a course section with certificate requirements that have been updated
3. Log out
4. As a student, sign in and enroll in the course section
5. Complete all certificate requirements",Instructor / Student,,,"The certificate requirements should be the updated requirements, not the original requirements",To Do,,,,Amanda Buddemeyer
CERT UPDATE,D,No update for existing section,"1. Sign in as a student in a course section with a certificate requirement that has changed since the section was created
2. Complete all of the certificate requirements from before the change",Student,,,"1. Home page ""Course Progress"" widget should indicate that certificate is earned (after instructor approval, if that is configured for this certificate)
2. The student should be able to access the certificate",To Do,,,,Amanda Buddemeyer