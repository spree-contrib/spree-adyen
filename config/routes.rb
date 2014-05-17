Spree::Core::Engine.routes.draw do
  get "checkout/payment/adyen", to: "adyen_redirect#confirm", as: :adyen_confirmation
  post "adyen/notify", to: "adyen_notifications#notify"
  post "adyen/authorise3d", to: "adyen_redirect#authorise3d", as: :adyen_authorise3d
end
