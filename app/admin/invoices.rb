ActiveAdmin.register Invoice do
  menu parent: 'Billing', priority: 1
  
  # Permitted parameters
  permit_params :student_id, :program_id, :batch_id, :student_full_name, :student_id_number,
                :invoice_number, :total_price, :registration_fee, :late_registration_fee,
                :invoice_status, :last_updated_by, :created_by, :due_date,
                payment_transaction_attributes: %i[id finance_approval_status payment_method_id account_holder_fullname 
                phone_number account_number transaction_reference receipt_image _destroy]

  # Scopes
  scope :all, default: true
  scope :unpaid
  scope :pending
  scope :approved
  scope :denied
  scope :incomplete
  # scope :due_date_passed
  scope :recently_added

  # Filters
  filter :invoice_number
  filter :student_full_name_cont, as: :string, label: 'Student Name'
  filter :student_id_number_cont, as: :string, label: 'Student ID'
  filter :program_id, as: :search_select_filter, url: proc { admin_programs_path },
                      fields: %i[program_name id], display_name: 'program_name', minimum_input_length: 2,
                      order_by: 'created_at_asc'
  filter :batch_id, as: :search_select_filter, url: proc { admin_batches_path },
                      fields: %i[batch_title id], display_name: 'batch_title', minimum_input_length: 2,
                      order_by: 'created_at_asc'
  filter :invoice_status, as: :select, collection: ['unpaid', 'pending', 'approved', 'denied', 'incomplete']
  filter :due_date
  filter :created_at
  filter :updated_at

  # Batch actions
  # batch_action :approve do |ids|
  #   batch_action_collection.find(ids).each do |invoice|
  #     invoice.update(invoice_status: 'approved')
  #     invoice.payment_transaction&.update(finance_approval_status: 'approved')
  #   end
  #   redirect_to collection_path, notice: "#{ids.size} invoices approved"
  # end

  # batch_action :deny do |ids|
  #   batch_action_collection.find(ids).each do |invoice|
  #     invoice.update(invoice_status: 'denied')
  #     invoice.payment_transaction&.update(finance_approval_status: 'denied')
  #   end
  #   redirect_to collection_path, notice: "#{ids.size} invoices denied"
  # end

  index do
    selectable_column
    # column "Invoice NO",:invoice_number
    column "Invoice #", :invoice_number, sortable: :invoice_number do |invoice|
      link_to invoice.invoice_number, admin_invoice_path(invoice)
    end
    column :student_full_name
    column :student_id_number
    column :program do |m|
      link_to m.program.program_name, [:admin, m.program] if m.program
    end
    column :batch do |m|
      link_to m.batch.batch_title, [:admin, m.batch] if m.batch
    end
    column :invoice_status do |s|
      status_tag s.invoice_status
    end
    number_column :total_price, as: :currency, unit: 'ETB', format: '%n %u', delimiter: ',', precision: 2
    column :due_date
    column 'Created At', sortable: true do |c|
      c.created_at.strftime('%b %d, %Y')
    end
    actions
  end


  action_item :approve, only: :show, if: proc { resource.invoice_status != 'approved' } do
    link_to 'Approve Invoice', approve_admin_invoice_path(resource), method: :put, data: { confirm: 'Are you sure you want to approve this invoice?' }, class: 'btn btn-success'
  end

  member_action :approve, method: :put do
    resource.payment_transaction&.update(finance_approval_status: 'approved')
    
    resource.update(invoice_status: 'approved')
    course_registration = resource.invoice_items.first.course_registration
    course_registration.update(enrollment_status: 'enrolled')
    course_registration.add_grade
    testmoodle
    Notification.create!(
            student_id: resource.student_id,
            notifiable: resource,
            notification_status: 'success',
            notification_message: "Thank you for your payment! Your invoice has been approved. You can now access the LMS using the username and password provided below and learn",
            notification_card_color: "success",
            notification_action: "approved"
        )
    redirect_to resource_path, notice: 'Invoice approved.'
  end
  action_item :deny, only: :show, if: proc { resource.invoice_status != 'denied' } do
  link_to 'Deny Invoice', deny_admin_invoice_path(resource), method: :put, data: { confirm: 'Are you sure you want to deny this invoice?' }, class: 'btn btn-danger'
  end

  member_action :deny, method: :put do
    resource.update(invoice_status: 'denied')
    resource.payment_transaction&.update(finance_approval_status: 'denied')
    Notification.create!(
            student_id: resource.student_id,
            notifiable: resource,
            notification_status: 'danger',
            notification_message: "your payment inovice is not approved please transfer to our account and re-submit the slip",
            notification_card_color: "danger",
            notification_action: "pay"
        )
    redirect_to resource_path, notice: 'Invoice denied.'
  end
  # Show page
  show title: proc { |invoice| "Invoice ##{invoice.invoice_number}" } do
    columns do
      column do
        panel 'Invoice Details' do
          attributes_table_for invoice do
            row :invoice_number
            row :student_full_name
            row :student_id_number
            row :program do |m|
              link_to m.program.program_name, [:admin, m.program]
            end
            row :batch do |m|
              link_to m.batch.batch_title, [:admin, m.batch]
            end
            row :total_price do
              number_to_currency(invoice.total_price, unit: 'ETB ')
            end
            # row :registration_fee do
            #   number_to_currency(invoice.registration_fee, unit: 'ETB ')
            # end
            # row :late_registration_fee do
            #   number_to_currency(invoice.late_registration_fee, unit: 'ETB ')
            # end
            row :invoice_status do |s|
              status_tag s.invoice_status
            end
            row :due_date
            row :created_by
            row :last_updated_by
            row :created_at
            row :updated_at
          end
        end
      end

      column do
        panel 'Payment Transaction' do
          if invoice.payment_transaction.present?
            attributes_table_for invoice.payment_transaction do
              row :payment_method do |m|
                link_to m.payment_method.bank_name, [:admin, m.payment_method]
              end
              row :account_holder_fullname
              row :phone_number
              row :account_number
              row :transaction_reference
              row :receipt_image do |pt|
                if pt.receipt_image.attached?
                  link_to 'View Receipt', rails_blob_path(pt.receipt_image, disposition: 'inline'), target: '_blank'
                else
                  'No receipt attached'
                end
              end
              row :finance_approval_status do |pt|
                status_tag pt.finance_approval_status
              end
            end
          else
            'No payment transaction recorded.'
          end
        end

        panel 'Invoice Items' do
          if invoice.invoice_items.any?
            table_for invoice.invoice_items do
              column :course do |item|
                link_to item.course_registration.course_title, admin_course_path(item.course_registration.course)
              end
              column :price do |item|
                number_to_currency(item.price, unit: 'ETB ')
              end
              column :created_at
            end
          else
            'No items found for this invoice.'
          end
        end
      end
    end
  end

  # Form
  form do |f|
    f.semantic_errors
    if !f.object.new_record?
      f.inputs 'Invoice Information' do
        f.input :invoice_status, as: :select, collection: ['approved', 'denied']
        f.input :last_updated_by, input_html: { value: current_admin_user.name }, as: :hidden
      end
    end
    if !f.object.new_record?
      f.inputs 'Payment Transaction', for: [:payment_transaction, f.object.payment_transaction || f.object.build_payment_transaction] do |pt|
        pt.input :finance_approval_status, as: :select, collection: %w[pending approved denied]
      end
    end

    f.actions
  end

  # Controller
  controller do
    def testmoodle
      if @invoice.invoice_status == 'approved'
        @moodle = MoodleRb.new('ebf389740b514fdfa03fc804d767f127', 'https://www.nuf.edu.et/webservice/rest/server.php')
        unless @moodle.users.search(email: "#{@invoice.student.email}").present?
          student = @moodle.users.create(
              username: "#{@invoice.student.student_id.downcase}",
              password: "#{@invoice.student.student_password}",
              firstname: "#{@invoice.student.first_name}",
              lastname: "#{@invoice.student.last_name}",
              email: "#{@invoice.student.email}"
            )
          lms_student = @moodle.users.search(email: "#{@invoice.student.email}")
          @user = lms_student[0]['id']
          @invoice.student.course_registrations.each do |c|
            s = @moodle.courses.search("#{c.course.course_code}")
            @course = s['courses'].to_a[0]['id']
            @moodle.enrolments.create(
              user_id: "#{@user}",
              course_id: "#{@course}"
            )
          end
        end
      end
    end
    def scoped_collection
      super.includes(:program, :batch, :payment_transaction)
    end
  end
end
