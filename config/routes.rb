Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: 'dev_ex#index'

  get 'ref', to: 'dev_ex#ref'

  get 'description', to: 'dev_ex#description'

  get 'start_date', to: 'dev_ex#start_date'
end
