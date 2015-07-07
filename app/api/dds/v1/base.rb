module DDS
  module V1
    class Base < Grape::API
      version 'v1', using: :path
      content_type :json, 'application/json'
      format :json
      default_format :json
      formatter :json, Grape::Formatter::ActiveModelSerializers
      prefix :api

      helpers do
        def logger
          Rails.logger
        end

        def authenticate!
          unless current_user
            @auth_error[:error] = 401
            error!(@auth_error, 401)
          end
        end

        def current_user
          if @current_user
            return @current_user
          end
          api_token = headers["Authorization"]
          if api_token
            begin
              decoded_token = JWT.decode(api_token, Rails.application.secrets.secret_key_base)[0]
              @current_user = find_user_with_token(decoded_token)
            rescue JWT::VerificationError
              @current_user = nil
              @auth_error = {
                reason: 'invalid api_token',
                suggestion: 'token not properly signed'
              }
            rescue JWT::ExpiredSignature
              @current_user = nil
              @auth_error = {
                reason: 'expired api_token',
                suggestion: 'you need to login with your authenticaton service'
              }
            end
          else
            @auth_error = {
              error: 400,
              reason: 'no api_token',
              suggestion: 'you might need to login through an authenticaton service'
            }
            error!(@auth_error, 400)
          end
          @current_user
        end

        def find_user_with_token(decoded_token)
          User.find(decoded_token['id'])
        end

      end

      mount DDS::V1::UserAPI
      mount DDS::V1::SystemPermissionsAPI
      mount DDS::V1::AppAPI
      mount DDS::V1::CurrentUserAPI
      mount DDS::V1::ProjectsAPI
      mount DDS::V1::ProjectAffiliatesAPI
    end
  end
end