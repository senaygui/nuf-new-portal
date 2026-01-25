class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= AdminUser.new

    case user.role

    when 'admin'
      # can :manage, ActiveAdmin::Page, name: "Calendar", namespace_name: "admin"
      can :manage, CourseRegistration
      # can :manage, StudentGrade
      can :manage, AdminUser
      can :manage, ActiveAdmin::Page, name: 'InstructorReport', namespace_name: 'admin'
      can :manage, ActiveAdmin::Page, name: 'Dashboard', namespace_name: 'admin'
      # can :manage, ActiveAdmin::Page, name: 'StudentStats', namespace_name: 'admin'
      can :manage, ActiveAdmin::Page, name: 'Graduation', namespace_name: 'admin'
      can :manage, ActiveAdmin::Page, name: 'AssignSection', namespace_name: 'admin'

      can :manage, Program
      can :manage, Course
      can :manage, Student
      can :manage, PaymentMethod
      # can :manage, Batch
      can :manage, Invoice
    when 'instructor'
      can :manage, ActiveAdmin::Page, name: 'Dashboard', namespace_name: 'admin'
      can :read, AcademicCalendar
      can :read, Course, id: Course.instructor_courses(user.id)
      can :update, Course, id: Course.instructor_courses(user.id)
      can :manage, AssessmentPlan, admin_user_id: user.id
      can %i[read update], MakeupExam
      can :read, CourseRegistration, course_id: Course.instructor_courses(user.id)
      can %i[read update], StudentGrade, course_id: Section.instructors(user.id)
      can %i[read destroy], StudentGrade, course_id: Course.instructor_courses(user.id)
      can :read, Notice
      can :read, StudentGrade, course_id: Course.instructor_courses(user.id)
      can :update, StudentGrade, course_id: Course.instructor_courses(user.id)
      # Destroy action with a block for additional conditions
      can :destroy, StudentGrade do |grade|
        Course.instructor_courses(user.id).include?(grade.course_id) && grade.created_at >= 15.days.ago
      end
      can :read, Program
      # cannot :destroy, StudentGrade
      # can %i[create read destroy], Assessment, admin_user_id: user.id
      can :manage, Attendance
      # can :update, Attendance, section_id: Section.instructor_courses(user.id)
      # can :manage, Session
      # can :read, Session, course_id: Section.instructors(user.id)
      # can :update, Session, course_id: Section.instructors(user.id)
      # cannot :destroy, Session, course_id: Section.instructors(user.id)
      can :read, GradeChange, course_id: Section.instructors(user.id)
      can :update, GradeChange, course_id: Section.instructors(user.id)
      can :manage, ActiveAdmin::Page, name: 'Dashboard', namespace_name: 'admin'
      can :manage, ActiveAdmin::Page, name: 'FinanceReport', namespace_name: 'admin'

      can :read, Program
      # TODO: after one college created disable new action
      # cannot :destroy, College, id: 1

      can :read, Department
      can :read, CourseModule
      can :read, Course
      can :read, Student
      can :manage, PaymentMethod
      can :read, AcademicCalendar
      can :manage, CollegePayment
      can :read, SemesterRegistration
      can :manage, Invoice
    when 'registrar head'
      # can :manage, Assessment
      can :manage, AddCourse
      can :manage, Dropcourse
      can :read, UneditableCurriculum
      can %i[read update], Transfer
      can :manage, ActiveAdmin::Page, name: 'Dashboard', namespace_name: 'admin'
      can :manage, ActiveAdmin::Page, name: 'StudentStats', namespace_name: 'admin'
      can :manage, ActiveAdmin::Page, name: 'OnlineStudentGrade', namespace_name: 'admin'
      can :manage, ActiveAdmin::Page, name: 'AssignSection', namespace_name: 'admin'
      can :manage, AcademicCalendar
      can :manage, AdminUser, role: 'registrar head'
      can %i[read update], Exemption # , dean_approval_status: 'dean_approval_approved'
      can :manage, Faculty
      can :read, CourseModule
      can :read, Program
      can :read, Curriculum
      can :read, Course
      can %i[update read], GradeSystem
      can :read, AssessmentPlan
      can :manage, Section
      can :manage, Student
      can :manage, SemesterRegistration
      can :manage, CourseRegistration
      can :read, CollegePayment
      can :read, PaymentMethod
      can :read, Invoice
      can :manage, Attendance
      can :manage, Session
      can %i[read update], MakeupExam
      can %i[update read], GradeReport
      cannot :destroy, GradeReport
      can :read, StudentGrade
      can :manage, GradeChange
      can :manage, Withdrawal
      can :destroy, Withdrawal, created_by: user.name.full
      can %i[read update], ProgramExemption
      # can :manage, AddAndDrop
      # cannot :destroy, AddAndDrop, created_by: 'self'
      can %i[update destroy], Notice, created_by: user.name.full
      can :read, Notice
    when 'data encoder'
      can :manage, ActiveAdmin::Page, name: 'Dashboard', namespace_name: 'admin'
      can :manage, AcademicCalendar
      can :manage, AdminUser, role: 'instructor'
      can :manage, Faculty
      can :manage, Department
      can :read, CourseModule
      can :read, Program
      can :read, Curriculum
      can :read, Course
      can %i[update read], GradeSystem
      can :read, AssessmentPlan
      can :manage, Section
      can :manage, Student
      can :manage, SemesterRegistration
      can :manage, CourseRegistration
      can :read, CollegePayment
      can :read, PaymentMethod
      can :read, Invoice
      can :manage, Attendance
      can :manage, Session

      # can [:update, :read], GradeReport
      # cannot :destroy, GradeReport
      can :read, StudentGrade
      can :manage, GradeChange
      can :manage, Withdrawal
      can :destroy, Withdrawal, created_by: user.name.full

      can :manage, AddAndDrop
      cannot :destroy, AddAndDrop, created_by: 'self'

      can :manage, CourseSection
      can :manage, ActiveAdmin::Page, name: 'Dashboard', namespace_name: 'admin'
      can :manage, Student, admission_type: 'extention'
      can :read, AcademicCalendar, admission_type: 'extention'
      can :read, Program, admission_type: 'extention'
      can :manage, Department
      can :read, CourseModule
      can :read, Course
      can :manage, SemesterRegistration, admission_type: 'extention'
      can :read, Invoice
    when 'finance head'
      can :manage, ActiveAdmin::Page, name: 'Dashboard', namespace_name: 'admin'
      can :manage, ActiveAdmin::Page, name: 'FinanceReport', namespace_name: 'admin'
      can :manage, ActiveAdmin::Page, name: 'Dashboard', namespace_name: 'admin'
      can :manage, ActiveAdmin::Page, name: 'StudentStats', namespace_name: 'admin'

      can %i[read update], MakeupExam
      can %i[read update], Withdrawal
      can %i[read update], AddCourse
      can %i[read update], ExternalTransfer
      can %i[read update], Readmission
      can :manage, Invoice
      can :manage, RecurringPayment
      can :manage, PaymentTransaction
      can :manage, OtherPayment
      can %i[read update], DocumentRequest
      can :manage, Payment
      cannot :destroy, Invoice
      can :manage, ActiveAdmin::Page, name: 'Dashboard', namespace_name: 'admin'
      can :read, Program
      # TODO: after one college created disable new action
      # cannot :destroy, College, id: 1

      can :read, Department
      can :read, CourseModule
      can :read, Course
      can :read, Student
      can :manage, PaymentMethod
      can :read, AcademicCalendar
      can :manage, CollegePayment
      can :read, SemesterRegistration

      can %i[update destroy], Notice, created_by: user.name.full
      can :read, Notice
    end
  end
end
