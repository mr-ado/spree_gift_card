Spree::OrderMailer.class_eval do
  def gift_card_email(card_id, order_id)
    @gift_card = Spree::GiftCard.find(card_id)
    @order = Spree::Order.find(order_id)
    subject = "#{Spree::Config[:site_name]} Gift Card"
    admin_email = "#{Spree::Config[:admin_email]} Gift Card"
    @gift_card.update_attribute(:sent_at, Time.now)
    mail(:to => @gift_card.email, :from => from_address, :cc => admin_email,:subject => subject)
  end
end
