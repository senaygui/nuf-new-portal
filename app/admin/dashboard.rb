ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc { I18n.t('active_admin.dashboard') }

  content title: proc { I18n.t('active_admin.dashboard') } do
    columns do
      column do
        panel 'Summary' do
          total_students = Student.count
          active_students = Student.where(account_status: 'Active').count
          graduated_students = Student.where(graduation_status: 'graduated').count
          paid_invoices = nil
          unpaid_invoices = nil
          if Object.const_defined?('Invoice')
            paid_invoices = Invoice.where(invoice_status: 'approved').count
            unpaid_invoices = Invoice.where(invoice_status: 'unpaid').count
          end

          div style: 'display:flex; gap:12px; flex-wrap:wrap;' do
            # Total Students
            div style: 'flex:1 1 180px; background:#2b7a78; color:#fff; padding:16px; border-radius:8px; box-shadow:0 2px 6px rgba(0,0,0,.08);' do
              div 'Total Students', style: 'font-size:12px; opacity:.9;'
              div total_students.to_s, style: 'font-size:28px; font-weight:700; margin-top:4px;'
            end

            # Active Students
            div style: 'flex:1 1 180px; background:#3d9970; color:#fff; padding:16px; border-radius:8px; box-shadow:0 2px 6px rgba(0,0,0,.08);' do
              div 'Active Students', style: 'font-size:12px; opacity:.9;'
              div active_students.to_s, style: 'font-size:28px; font-weight:700; margin-top:4px;'
            end

            # Graduated Students
            div style: 'flex:1 1 180px; background:#6c63ff; color:#fff; padding:16px; border-radius:8px; box-shadow:0 2px 6px rgba(0,0,0,.08);' do
              div 'Graduated Students', style: 'font-size:12px; opacity:.9;'
              div graduated_students.to_s, style: 'font-size:28px; font-weight:700; margin-top:4px;'
            end

            if Object.const_defined?('Invoice')
              # Paid Invoices
              div style: 'flex:1 1 180px; background:#17a2b8; color:#fff; padding:16px; border-radius:8px; box-shadow:0 2px 6px rgba(0,0,0,.08);' do
                div 'Paid Invoices', style: 'font-size:12px; opacity:.9;'
                div paid_invoices.to_s, style: 'font-size:28px; font-weight:700; margin-top:4px;'
              end

              # Unpaid Invoices
              div style: 'flex:1 1 180px; background:#dc3545; color:#fff; padding:16px; border-radius:8px; box-shadow:0 2px 6px rgba(0,0,0,.08);' do
                div 'Unpaid Invoices', style: 'font-size:12px; opacity:.9;'
                div unpaid_invoices.to_s, style: 'font-size:28px; font-weight:700; margin-top:4px;'
              end
            end
          end
        end
      end
    end
    columns do
      column do

        panel 'Students by Program' do
          data = Student.group(:program_id).count
          formatted = data.each_with_object({}) do |(pid, cnt), h|
            name = Program.find_by(id: pid)&.program_name || 'Unassigned'
            h[name] = cnt
          end
          div do
            pie_chart formatted, donut: true, legend: 'bottom', messages: { empty: 'No data' }
          end
        end

        panel 'Students by Gender' do
          div do
            pie_chart Student.group(:gender).count, legend: 'bottom', messages: { empty: 'No data' }
          end
        end
      end

      column do
        panel 'Students by Account Status' do
          div do
            column_chart Student.group(:account_status).count, library: { scales: { y: { beginAtZero: true } } }, messages: { empty: 'No data' }
          end
        end

        panel 'New Students per Month (Last 12 Months)' do
          # Uses PostgreSQL date_trunc for monthly grouping
          monthly = Student
                      .where('created_at >= ?', 12.months.ago.beginning_of_month)
                      .group(Arel.sql("DATE_TRUNC('month', created_at)"))
                      .order(Arel.sql("DATE_TRUNC('month', created_at)"))
                      .count
          series = monthly.transform_keys { |d| d.to_date.strftime('%Y-%m') }
          div do
            line_chart series, points: true, messages: { empty: 'No data' }
          end
        end

        if Object.const_defined?('Invoice')
          panel 'Invoices by Status' do
            div do
              bar_chart Invoice.group(:invoice_status).count, messages: { empty: 'No data' }
            end
          end

          panel 'Invoice Totals per Month (Last 12 Months)' do
            monthly_total = Invoice
                              .where('created_at >= ?', 12.months.ago.beginning_of_month)
                              .group(Arel.sql("DATE_TRUNC('month', created_at)"))
                              .order(Arel.sql("DATE_TRUNC('month', created_at)"))
                              .sum(:total_price)
            series = monthly_total.transform_keys { |d| d.to_date.strftime('%Y-%m') }
            div do
              area_chart series, messages: { empty: 'No data' }
            end
          end
        end
      end
    end
  end
end
