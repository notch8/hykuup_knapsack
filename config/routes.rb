# frozen_string_literal: true
HykuKnapsack::Engine.routes.draw do
end

Rails.application.routes.draw do
  if ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYKU_MULTITENANT', false))
    constraints host: Account.admin_host do
      namespace :proprietor do
        resources :showcases, only: :index do
          member do
            post :snapshot
            post :reset
          end
        end
      end
    end
  end

  # TODO: this route is a temporary fix for UV small image download not working
  get '/:file_path/full/:size/:rotation/:quality.:format',
    to: redirect { |params|
      encoded_path = params[:file_path].gsub('/', '%2F')
      "/images/#{encoded_path}/full/#{params[:size]}/#{params[:rotation]}/#{params[:quality]}.#{params[:format]}"
    },
    constraints: {
      file_path: /[a-f0-9-]+%2Ffiles%2F[a-f0-9-]+/,
      size: /[\d,!]+/,
      rotation: /\d+/,
      quality: /\w+/,
      format: /(jpg|png|gif|webp)/
    }
end
