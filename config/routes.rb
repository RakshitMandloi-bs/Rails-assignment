Rails.application.routes.draw do
  root 'sessions#new'

  # Auth routes
  get    '/signup',         to: 'users#new'
  post   '/signup',         to: 'users#create'
  get    '/login',          to: 'sessions#new'
  post   '/login',          to: 'sessions#create'
  delete '/logout',         to: 'sessions#destroy'

  # Profile routes
  get    '/profile',        to: 'users#edit'
  patch  '/profile',        to: 'users#update'

  # File management routes
  get    '/dashboard',      to: 'uploaded_files#index'
  post   '/upload',         to: 'uploaded_files#create'
  get    '/files/:id/download', to: 'uploaded_files#download'
  delete '/files/:id',      to: 'uploaded_files#destroy'
  patch  '/files/:id/share', to: 'uploaded_files#toggle_share'

  # Shared files routes
  get    '/shared/:token',  to: 'shared_files#show'
end
