module ScimRails
  module Response
    CONTENT_TYPE = "application/scim+json".freeze

    def json_response(object, status = :ok)
      render \
        json: object,
        status: status,
        content_type: CONTENT_TYPE
    end

    def json_scim_response(object:, status: :ok, counts: nil,  schema: ScimRails.config.user_schema)
      case params[:action]
      when "index"
        render \
          json: list_response(object, counts, schema),
          status: status,
          content_type: CONTENT_TYPE
      when "show", "create", "put_update", "patch_update"
        render \
          json: object_response(object, schema),
          status: status,
          content_type: CONTENT_TYPE
      end
    end

    private
    
    def list_response(object, counts, schema)
      object = object
        .order(:id)
        .offset(counts.offset)
        .limit(counts.limit)
      {
        "schemas": [
            "urn:ietf:params:scim:api:messages:2.0:ListResponse"
        ],
        "totalResults": counts.total,
        "startIndex": counts.start_index,
        "itemsPerPage": counts.limit,
        "Resources": list_objects(object, schema)
      }
    end

    def list_objects(objects, schema)
      objects.map do |object|
        object_response(object, schema)
      end
    end

    def object_response(object, schema)
      find_value(object, schema)
    end
      
    # `find_value` is a recursive method that takes a "user" and a
    # "user schema" and replaces any symbols in the schema with the
    # corresponding value from the user. Given a schema with symbols,
    # `find_value` will search through the object for the symbols,
    # send those symbols to the model, and replace the symbol with
    # the return value.

    def find_value(user, object)
      case object
      when Hash
        object.each.with_object({}) do |(key, value), hash|
          hash[key] = find_value(user, value)
        end
      when Array
        object.map do |value|
          find_value(user, value)
        end
      when Symbol
        user.public_send(object)
      else
        object
      end
    end
  end
end
