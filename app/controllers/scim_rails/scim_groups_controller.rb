require 'pry' 

module ScimRails
  class ScimGroupsController < ScimRails::ApplicationController
    SCHEMA = ScimRails.config.group_schema

    def index
      if params[:filter].present?
        query = ScimRails::ScimQueryParser.new(params[:filter], ScimRails.config.queryable_group_attributes)

        groups = @company
          .public_send(ScimRails.config.scim_groups_scope)
          .where(
            "#{ScimRails.config.scim_groups_model.connection.quote_column_name(query.attribute)} #{query.operator} ?",
            query.parameter
          )
          .order(ScimRails.config.scim_groups_list_order)
      else
        groups = @company
          .public_send(ScimRails.config.scim_groups_scope)
          .order(ScimRails.config.scim_groups_list_order)
      end

      counts = ScimCount.new(
        start_index: params[:startIndex],
        limit: params[:count],
        total: groups.count
      )
      
      json_scim_response(object: groups, counts: counts, schema: SCHEMA)
    end

    def show
      group = @company.public_send(ScimRails.config.scim_groups_scope).find(params[:id])
      json_scim_response(object: group, schema: SCHEMA)
    end

    def create
      if ScimRails.config.scim_user_prevent_update_on_create
        group = @company.public_send(ScimRails.config.scim_groups_scope).create!(permitted_group_params)
      else
        groupname_key = ScimRails.config.queryable_group_attributes[:displayName]
        find_by_groupname = Hash.new
        find_by_groupname[groupname_key] = permitted_group_params[groupname_key]
        group = @company
          .public_send(ScimRails.config.scim_groups_scope)
          .find_or_create_by(find_by_groupname)
        group.update!(permitted_group_params)
      end
      update_status(group) unless put_active_param.nil?
      json_scim_response(object: group, status: :created, schema: SCHEMA)
    end

    def update
      group = @company.public_send(ScimRails.config.scim_groups_scope).find(params[:id])
      results = parse_operations(params['Operations'], group).flatten.compact
      json_scim_response(object: group, schema: SCHEMA)
    end

    def destroy
      group = @company.public_send(ScimRails.config.scim_groups_scope).find(params[:id])
      group.delete
    end

    private

    def permitted_group_params
      ScimRails.config.mutable_group_attributes.each.with_object({}) do |attribute, hash|
        hash[attribute] = find_value_for(attribute)
      end
    end

    def update_status(group)
      group.public_send(ScimRails.config.group_reprovision_method) if active?
      group.public_send(ScimRails.config.group_deprovision_method) unless active?
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

    def find_value_for(attribute, hash = nil)
      hash ||= params
      hash.dig(*path_for(attribute))
    end

    def put_active_param
      params[:active]
    end

    # `path_for` is a recursive method used to find the "path" for
    # `.dig` to take when looking for a given attribute in the
    # params.
    #
    # Example: `path_for(:name)` should return an array that looks
    # like [:names, 0, :givenName]. `.dig` can then use that path
    # against the params to translate the :name attribute to "John".

    def path_for(attribute, object = ScimRails.config.mutable_group_attributes_schema, path = [])
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

    def parse_operations(operations, target)
      operations.map do |operation|
        parse_operation(operation, target)
      end
    end

    def parse_operation(operation, target)
      case operation['op']
      when 'replace'
        attributes = ScimRails.config.mutable_group_attributes.each.with_object({}) do |attribute, hash|
          hash[attribute] = find_value_for(attribute, operation['value'])
        end
        target.update!(attributes)
        target
      when 'add'
        # Assume for this use case that only users can be added to groups
        raise ScimRails::ExceptionHandler::UnsupportedPatchRequest unless operation['path'] == 'members'
        operation['value'].map do |value|
          user_id = value['value']
          user = ScimRails.config.scim_users_model.find(user_id)
          target.public_send(ScimRails.config.scim_users_scope) << user
        end
      when 'remove'
        user = find_user(operation['path'])
        target.public_send(ScimRails.config.scim_users_scope).delete(user)
      else
        raise ScimRails::ExceptionHandler::UnsupportedPatchRequest
      end
    end

    def find_user(path)
      match = parse_path(path)
      if match[:member] != 'members' || match[:attribute] != 'value' || match[:operator] != 'eq'
        return nil
      end
      ScimRails.config.scim_users_model.find(match[:target])
    end

    def parse_path(path)
      path.match(/\A(?<member>.*)\[(?<attribute>\w+) (?<operator>\w+) (?<target>"?[\w|-]+"?)\]\Z/)
    end
  end
end