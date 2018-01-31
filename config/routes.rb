Rails.application.routes.draw do
  get 'kitaguchi', :to => 'kitaguchi#index'

  get 'javascript_test/index'

  get 'users/:domain_name/:screen_name',
    :controller => 'users',
    :to => 'users#show',
    :constraints => {:domain_name => /(.*?)/}

  get 'users/authorize',
    :controller => 'users',
    :to => 'users#authorize'

  get 'users/authorize_callback',
    :controller => 'users',
    :to => 'users#authorize_callback'

  patch 'users/update', :to => 'users#update'
  post 'users/update', :to => 'users#update'


  get 'users/login'

  get 'users/login_complete'

  get 'users/logout'

  get 'documents/editor_demo', :to => 'documents#demo'
  get 'documents/:id/histories', :to => 'documents#histories'
  get 'documents/:id/diff', :to => 'documents#diff'
  post 'documents/authorize', :to => 'documents#authorize'
  post 'documents/migrate', :to => 'documents#migrate'
  resources :documents

  namespace :drive do
    get 'documents/new', :to => 'documents#new'
    resources :documents, :only => [:show, :update]
  end

  scope :drive do
    get 'installed', :to => 'welcome#installed'
  end

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
