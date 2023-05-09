Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: 'dev_ex#index'

  get 'ref', to: 'dev_ex#ref'
end
