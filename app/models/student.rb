class Student < ApplicationRecord
  # Include default devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable
  
  # Callbacks
  after_create :student_id_generator
  after_create :assign_batch
  before_create :set_pwd
  # after_save :create_one_course_registration
  after_create :enroll_all_program_courses
  after_create :notify_student_created

  # Enroll all courses from the student's program to student_courses after creation
  def enroll_all_program_courses
    return unless program && program.courses.any?
    program.courses.each do |course|
      StudentCourse.create(course_id: course.id, student_id: id,course_title: course.course_title, created_by: "system") unless student_courses.exists?(course_id: course.id)
    end
  end
  def notify_student_created
    Notification.create!(
      notifiable: self,
      student_id: self.id,
      notification_status: 'success',
      notification_message: "Congratulations! You are successfully registered. Click the 'Enroll' button to enroll in course.",
      notification_card_color: "success",
      notification_action: "create"
    )
  end
  
  # Associations
  belongs_to :program, optional: true
  belongs_to :batch, optional: true
  has_one_attached :photo
  has_many :invoices, dependent: :destroy
  has_many :student_courses, dependent: :destroy
  has_many :courses, through: :student_courses
  has_many :course_registrations, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy
  
  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, :gender, :date_of_birth, presence: true
  validates :moblie_number, presence: true, length: { minimum: 10, maximum: 25 }
  validates :country, presence: true, inclusion: { in: ISO3166::Country.codes, message: "is not a valid country code" }
  validates :account_status, inclusion: { in: %w[active inactive suspended], message: "%{value} is not a valid status" }
  validates :student_id, uniqueness: true, allow_blank: true
  validate :validate_date_of_birth
  validate :password_complexity
  
  # Scopes
  scope :recently_added, -> { where('created_at >= ?', 1.week.ago) }
  scope :active, -> { where(account_status: 'Active') }
  scope :inactive, -> { where(account_status: 'inactive') }
  scope :suspended, -> { where(account_status: 'suspended') }
  scope :by_program, ->(program_id) { where(program_id: program_id) if program_id.present? }
  scope :by_batch, ->(batch_id) { where(batch_id: batch_id) if batch_id.present? }
  

  def generate_invoice
    return unless program
    invoices.create(
      invoice_number: "INV-#{SecureRandom.hex(4).upcase}",
      program_id: program.id,
      batch_id: batch.id,
      total_price: program.courses.sum(:course_price),
      due_date: Date.current + 30.days,
      created_by: 'system',
      student_id: id,
      student_full_name: full_name,
      student_id_number: student_id
    )
  end
  # Instance Methods
  
  # Returns the full name of the student
  def full_name
    [first_name, middle_name, last_name].compact.join(' ').squish
  end
  
  # Returns full name with student ID in parentheses
  def full_name_with_id
    "#{full_name} (#{student_id})"
  end
  
  # Override Devise method to check if account is active
  def active_for_authentication?
    super && account_active?
  end
  
  # Check if account is active
  def account_active?
    account_status == 'active'
  end
  
  # Devise method for custom inactive message
  def inactive_message
    if account_status == 'suspended'
      :suspended
    else
      :inactive
    end
  end
  
  # Get student's age based on date of birth
  # def age
  #   return nil unless date_of_birth.present?
  #   now = Time.zone.now.to_date
  #   now.year - date_of_birth.year - ((now.month > date_of_birth.month || 
  #     (now.month == date_of_birth.month && now.day >= date_of_birth.day)) ? 0 : 1)
  # end
  
  # Check if student is a minor (under 18)
  def minor?
    return false unless date_of_birth.present?
    age <= 18
  end
  
  # Generate a temporary password
  def self.generate_temporary_password(length = 12)
    chars = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten
    (0...length).map { chars[rand(chars.length)] }.join
  end
  
  # Search students by name, email, or student ID
  def self.search(query)
    return all if query.blank?
    
    where("first_name ILIKE :query OR 
           last_name ILIKE :query OR 
           email ILIKE :query OR 
           student_id = :exact_query", 
           query: "%#{query}%", exact_query: query)
  end
  
  private
  
  # Set default values for new records
  def set_defaults
    self.country ||= 'ET'
    self.account_status ||= 'active'
    # self.student_password = password if password.present? && new_record?
  end
  def set_pwd
    self[:student_password] = password
  end
  
  # Generate a unique student ID
  def student_id_generator
    if !student_id.present?
      begin
        self.student_id = "#{program.program_code}/#{SecureRandom.random_number(1000..10_000)}/#{Time.now.strftime('%y')}"
      end while Student.where(student_id:).exists?
    end
  end
  
  # Assign a batch to the student after creation if not already assigned
  def assign_batch
    return if self.batch_id.present?
    today = Date.current
    # Find the batch for the student's program where today is between starting_date and ending_date
    if self.program_id.present?
      batch = Batch.where(program_id: self.program_id)
                   .where('starting_date <= ? AND ending_date >= ?', today, today)
                   .order(starting_date: :desc).first
      self.update_column(:batch_id, batch.id) if batch
    else
      # If no program, assign to any batch where today is between starting_date and ending_date
      batch = Batch.where('starting_date <= ? AND ending_date >= ?', today, today)
                   .order(starting_date: :desc).first
      self.update_column(:batch_id, batch.id) if batch
    end
  end
  
  # Validate date of birth
  def validate_date_of_birth
    return unless date_of_birth.present?
    
    if date_of_birth > Date.current
      errors.add(:date_of_birth, "can't be in the future")
    elsif date_of_birth < 100.years.ago
      errors.add(:date_of_birth, "is too far in the past")
    end
  end
  
  # Validate password complexity
  def password_complexity
    return if password.blank?
    
    unless password.match(/[a-z]/) && password.match(/[A-Z]/)
      errors.add(:password, 'must include at least one lowercase and one uppercase letter')
    end
    
    unless password.length.between?(8, 20)
      errors.add(:password, 'must be between 8 to 20 characters')
    end
    
    unless password.match(/[0-9]/)
      errors.add(:password, 'must include at least one number')
    end
  end
  def set_pwd
    self[:student_password] = password
  end
end
