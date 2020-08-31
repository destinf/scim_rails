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
  end
end