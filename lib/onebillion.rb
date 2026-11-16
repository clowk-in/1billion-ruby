require_relative "onebillion/version"
require_relative "onebillion/errors"
require_relative "onebillion/client"
require_relative "onebillion/delivery_method"

# 1billion: transactional e-mail. See OneBillion::Client and OneBillion::DeliveryMethod.
module OneBillion
end

if defined?(ActionMailer)
  ActionMailer::Base.add_delivery_method(:onebillion, OneBillion::DeliveryMethod)
elsif defined?(ActiveSupport)
  ActiveSupport.on_load(:action_mailer) { add_delivery_method(:onebillion, OneBillion::DeliveryMethod) }
end
