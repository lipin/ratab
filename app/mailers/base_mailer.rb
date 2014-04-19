# coding: utf-8
class BaseMailer < ActionMailer::Base
  default :from => Setting.email_sender
  default :charset => "utf-8"
  default :content_type => "text/html"

  layout 'mailer'
end
