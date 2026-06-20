class ChapaPaymentsController < ApplicationController
  require 'net/http'
  require 'uri'
  require 'json'

  # Make sure student is authenticated, or skip if webhook
  before_action :authenticate_student!, except: [:webhook]
  skip_before_action :verify_authenticity_token, only: [:webhook]

  def initialize_payment
    @invoice = Invoice.find(params[:invoice_id])
    
    # Generate unique transaction reference (max 50 chars)
    # Using first 8 chars of invoice UUID + random hex to ensure uniqueness while staying under limit
    tx_ref = "inv-#{@invoice.id.to_s[0..7]}-#{SecureRandom.hex(8)}"
    
    amount = (@invoice.total_price + @invoice.registration_fee).round(2)
    
    uri = URI.parse("https://api.chapa.co/v1/transaction/initialize")
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    
    # Use ENV variable or a placeholder if not set
    secret_key = ENV['CHAPA_SECRET_KEY'] || 'CHASECK_TEST-rwi3K9wQM6anMi9PTAFECMxMLsNjJKpA'
    request["Authorization"] = "Bearer #{secret_key}"
    
    payload = {
      amount: amount.to_s,
      currency: "ETB",
      email: @invoice.student.email,
      first_name: @invoice.student.first_name || "Student",
      last_name: @invoice.student.last_name || "User",
      tx_ref: tx_ref,
      callback_url: chapa_webhook_url, 
      return_url: chapa_verify_url(tx_ref: tx_ref, invoice_id: @invoice.id),
      customization: {
        title: "Nuf Africa",
        description: "Payment for Invoice #{@invoice.invoice_number}"
      }
    }
    
    request.body = JSON.dump(payload)
    
    req_options = {
      use_ssl: uri.scheme == "https",
    }
    
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
    
    result = JSON.parse(response.body)
    
    if result["status"] == "success"
      checkout_url = result["data"]["checkout_url"]
      redirect_to checkout_url
    else
      redirect_to invoice_path(@invoice), alert: "Failed to initialize Chapa payment: #{result["message"]}"
    end
  end

  def verify
    tx_ref = params[:tx_ref]
    @invoice = Invoice.find(params[:invoice_id])
    
    uri = URI.parse("https://api.chapa.co/v1/transaction/verify/#{tx_ref}")
    request = Net::HTTP::Get.new(uri)
    secret_key = ENV['CHAPA_SECRET_KEY'] || 'CHASECK_TEST-rwi3K9wQM6anMi9PTAFECMxMLsNjJKpA'
    request["Authorization"] = "Bearer #{secret_key}"
    
    req_options = {
      use_ssl: uri.scheme == "https",
    }
    
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
    
    result = JSON.parse(response.body)
    
    if result["status"] == "success"
      handle_successful_payment(@invoice, tx_ref)
      redirect_to root_path, notice: "Payment was successfully processed via Chapa."
    else
      Rails.logger.error("Chapa Verification Failed: #{result.inspect}")
      redirect_to invoice_path(@invoice), alert: "Payment verification failed: #{result["message"] || 'Unknown error'}. Please contact support."
    end
  end
  
  def webhook
    # Optional asynchronous webhook. Simply return 200 OK.
    render json: { status: "success" }
  end

  private

  def handle_successful_payment(invoice, tx_ref)
    # Check if we already created a payment transaction
    return if invoice.payment_transaction.present? && invoice.payment_transaction.finance_approval_status == 'approved'
    
    # We create a payment method if it doesn't exist
    payment_method = PaymentMethod.find_by(bank_name: "Chapa Online Payment")
    unless payment_method
      payment_method = PaymentMethod.new(
        bank_name: "Chapa Online Payment",
        account_full_name: "Chapa Integration",
        account_number: "ONLINE",
        payment_method_type: "Online"
      )
      payment_method.save(validate: false)
    end
    
    transaction = invoice.build_payment_transaction(
      account_holder_fullname: invoice.student_full_name,
      account_number: "CHAPA-#{tx_ref[0..8]}",
      transaction_reference: tx_ref,
      finance_approval_status: "approved",
      payment_method_id: payment_method.id
    )
    
    if transaction.save(validate: false)
      invoice.update_columns(invoice_status: "approved")
      
      # Execute approval side-effects (like the admin panel)
      course_registration = invoice.invoice_items.first&.course_registration
      if course_registration
        course_registration.update(enrollment_status: 'enrolled')
        course_registration.add_grade
      end
      
      enroll_in_moodle(invoice)
      
      Notification.create!(
        student_id: invoice.student_id,
        notifiable: invoice,
        notification_status: 'success',
        notification_message: "Thank you for your payment! Your invoice has been approved. You can now access the LMS using the username and password provided below and learn",
        notification_card_color: "success",
        notification_action: "approved"
      )
    end
  end

  def enroll_in_moodle(invoice)
    if invoice.invoice_status == 'approved'
      moodle = MoodleRb.new('ebf389740b514fdfa03fc804d767f127', 'https://www.nuf.edu.et/webservice/rest/server.php')
      unless moodle.users.search(email: invoice.student.email.to_s).present?
        student = moodle.users.create(
            username: invoice.student.student_id.to_s.downcase,
            password: invoice.student.student_password.to_s,
            firstname: invoice.student.first_name.to_s,
            lastname: invoice.student.last_name.to_s,
            email: invoice.student.email.to_s
          )
        lms_student = moodle.users.search(email: invoice.student.email.to_s)
        user_id = lms_student[0]['id']
        invoice.student.course_registrations.each do |c|
          s = moodle.courses.search(c.course.course_code.to_s)
          course_id = s['courses'].to_a[0]['id']
          moodle.enrolments.create(
            user_id: user_id.to_s,
            course_id: course_id.to_s
          )
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error("Moodle Integration Failed: #{e.message}")
  end
end
