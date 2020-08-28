module ScimRails
  class ScimUsersController < ScimRails::ApplicationController
    def index
      if params[:filter].present?
        query = ScimRails::ScimQueryParser.new(params[:filter])

        users = @company
          .public_send(ScimRails.config.scim_users_scope)
          .where(
            "#{ScimRails.config.scim_users_model.connection.quote_column_name(query.attribute)} #{query.operator} ?",
            query.parameter
          )
          .order(ScimRails.config.scim_users_list_order)
      else
        users = @company
          .public_send(ScimRails.config.scim_users_scope)
          .order(ScimRails.config.scim_users_list_order)
      end

      counts = ScimCount.new(
        start_index: params[:startIndex],
        limit: params[:count],
        total: users.count
      )

      json_scim_response(object: users, counts: counts)
    end

    def create
      binding.pry
      if ScimRails.config.scim_user_prevent_update_on_create
        user_params = permitted_user_params.reject {|k,v| v.class == Hash}
        user = @company.public_send(ScimRails.config.scim_users_scope).create!(user_params)
        associated_params = permitted_user_params.select {|k,v| v.class == Hash}
        associated_params.each do |assocation, param|
          create_association!(user, association, param)
        end
        # user = create_association!(@company, ScimRails.config.scim_users_scope, permitted_user_params)
      else
        username_key = ScimRails.config.queryable_user_attributes[:userName]
        find_by_username = Hash.new
        find_by_username[username_key] = permitted_user_params[username_key]
        user = @company
          .public_send(ScimRails.config.scim_users_scope)
          .find_or_create_by(find_by_username)
        # user.update!(permitted_user_params)
        update_association!(user, permitted_user_params)
      end
      update_status(user) unless put_active_param.nil?
      json_scim_response(object: user, status: :created)
    end

    def show
      user = @company.public_send(ScimRails.config.scim_users_scope).find(params[:id])
      json_scim_response(object: user)
    end

    def put_update
      user = @company.public_send(ScimRails.config.scim_users_scope).find(params[:id])
      update_status(user) unless put_active_param.nil?
      ActiveRecord::Base.transaction do
        update_association!(user, permitted_user_params)
      end
      json_scim_response(object: user)
    end

    # TODO: PATCH will only deprovision or reprovision users.
    # This will work just fine for Okta but is not SCIM compliant.
    def patch_update
      user = @company.public_send(ScimRails.config.scim_users_scope).find(params[:id])
      update_status(user)
      json_scim_response(object: user)
    end

    private

    def create_association!(association, key, params)
      association.send('build_' + key.to_s)
      direct_attributes = params.reject {|param| param.class == Hash }
      association_attributes = params.select {|param| param.class == Hash }
      association.save!(direct_attributes)
      association_attributes.each do |association_key, association_value|
        create_association!(association, association_key, association_value)
      end
    end

    def update_association!(association, params)
      direct_attributes = {}
      params.each do |key, value|
        case value
        when Hash
          new_association = association.send(key)
          if new_association
            update_association!(new_association, value)
          else
            create_association!(association, key, value)
          end
        else
          direct_attributes[key] = value
        end
      end
      association.update!(direct_attributes)
    end

    def attribute_array_to_hash(array, value)
      return {} if array.empty?
      result = value
      array.reverse.each do |e|
        result = Hash[e, result]
      end
      result
    end

    def permitted_user_params
      ScimRails.config.mutable_user_attributes.each.with_object({}) do |attribute, hash|
        case attribute
        when Array
          hash.deep_merge!(attribute_array_to_hash(attribute, find_value_for(attribute)))
        else
          hash[attribute] = find_value_for(attribute)
        end
      end
    end

    def find_value_for(attribute)
      params.dig(*path_for(attribute))
    end

    # `path_for` is a recursive method used to find the "path" for
    # `.dig` to take when looking for a given attribute in the
    # params.
    #
    # Example: `path_for(:name)` should return an array that looks
    # like [:names, 0, :givenName]. `.dig` can then use that path
    # against the params to translate the :name attribute to "John".

    def path_for(attribute, object = ScimRails.config.mutable_user_attributes_schema, path = [])
      at_path = path.empty? ? object : object.dig(*path)
      return path if at_path == attribute

      case at_path
      when Hash
        at_path.each do |key, value|
          found_path = path_for(attribute, object, [*path, key])
          return found_path if found_path
        end
        nil
      when Array
        at_path.each_with_index do |value, index|
          found_path = path_for(attribute, object, [*path, index])
          return found_path if found_path
        end
        nil
      end
    end

    def update_status(user)
      user.public_send(ScimRails.config.user_reprovision_method) if active?
      user.public_send(ScimRails.config.user_deprovision_method) unless active?
    end

    def active?
      active = put_active_param
      active = patch_active_param if active.nil?

      case active
      when true, "true", 1
        true
      when false, "false", 0
        false
      else
        raise ActiveRecord::RecordInvalid
      end
    end

    def put_active_param
      params[:active]
    end

    def patch_active_param
      handle_invalid = lambda do
        raise ScimRails::ExceptionHandler::UnsupportedPatchRequest
      end

      operations = params["Operations"] || {}

      valid_operation = operations.find(handle_invalid) do |operation|
        valid_patch_operation?(operation)
      end

      valid_operation.dig("value", "active")
    end

    def valid_patch_operation?(operation)
      operation["op"].casecmp("replace") &&
        operation["value"] &&
        [true, false].include?(operation["value"]["active"])
    end
  end
end