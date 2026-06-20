ActiveAdmin.register Course do
  permit_params :program_id, :course_title, :course_code, :course_description, :course_order, :course_starting_date,
                :course_ending_date, :course_price, :created_by, :last_updated_by, :course_outline, course_instructors_attributes: %i[id instructor_id _destroy], assessment_plans_attributes: %i[id name weight _destroy], course_prerequisites_attributes: %i[id prerequisite_id _destroy]

  index do
    selectable_column
    column :course_title
    column :course_code
    column :program, sortable: true do |m|
      link_to m.program.program_name, [:admin, m.program] if m.program
    end
    column :course_order
    column :course_starting_date
    column :course_ending_date
    column :course_price
    column :created_by
    column :last_updated_by
    actions
  end

  filter :program_id, as: :search_select_filter, url: proc { admin_programs_path },
                      fields: %i[program_name id], display_name: 'program_name', minimum_input_length: 2,
                      order_by: 'created_at_asc'
  filter :course_title
  filter :course_code
  filter :course_order
  filter :course_starting_date
  filter :course_ending_date
  filter :course_price
  filter :created_by
  filter :last_updated_by
  filter :created_at
  filter :updated_at

  form do |f|
    f.semantic_errors
    f.inputs 'Course Information' do
      f.input :program_id, as: :search_select, url: proc { admin_programs_path },
                           fields: %i[program_name id], display_name: 'program_name', minimum_input_length: 2,
                           order_by: 'created_at_asc'
      f.input :course_title
      f.input :course_code
      f.input :course_description
      f.input :course_order
      f.input :course_starting_date, as: :datepicker
      f.input :course_ending_date, as: :datepicker
      f.input :course_price
      f.input :created_by, input_html: { value: current_admin_user.name }, as: :hidden
      f.input :last_updated_by, input_html: { value: current_admin_user.name }, as: :hidden
    end
    f.has_many :course_prerequisites, allow_destroy: true, new_record: true do |cp|
      cp.input :prerequisite_id, as: :select, collection: Course.all.map { |c| [c.course_title, c.id] }
    end
    f.actions
  end

  show title: :course_title do
    attributes_table do
      row :program do |m|
        link_to m.program.program_name, [:admin, m.program] if m.program
      end
      row :course_title
      row :course_code
      row :course_description
      row :course_order
      row :course_starting_date
      row :course_ending_date
      row :course_price
      row :created_by
      row :last_updated_by
      row :created_at
      row :updated_at
    end
    panel 'Prerequisites' do
      table_for course.prerequisites do
        column :course_title
      end
    end
  end

  controller do
    def create
      params[:course][:created_by] = current_admin_user.name
      params[:course][:last_updated_by] = current_admin_user.name
      super
    end

    def update
      params[:course][:last_updated_by] = current_admin_user.name
      super
    end
  end
end
