Spree::Core::Engine.routes.draw do
  get "checkout/payment/adyen", to: "adyen_redirect#confirm"
  post "adyen/notify", to: "adyen_notifications#notify"
end
