Spree::Core::Engine.routes.draw do
  get "checkout/payment/adyen", to: "adyen_redirect#confirm", as: :adyen_confirmation
  post "adyen/notify", to: "adyen_notifications#notify"
end
