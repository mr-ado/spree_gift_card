require 'spree/core/validators/email'

module Spree
  class GiftCard < ActiveRecord::Base

    UNACTIVATABLE_ORDER_STATES = ["complete", "awaiting_return", "returned"]

    belongs_to :variant
    belongs_to :line_item

    has_many :transactions, class_name: 'Spree::GiftCardTransaction'

    validates :code,               presence: true, uniqueness: true
    validates :current_value,      presence: true
    validates :email, email: true, presence: true
    validates :name,               presence: true
    validates :original_value,     presence: true

    before_validation :generate_code, on: :create
    before_validation :set_calculator, on: :create
    before_validation :set_values, on: :create

    include Spree::CalculatedAdjustments

    def apply(order)
      # Nothing to do if the gift card is already associated with the order
      return if order.gift_credit_exists?(self)
      order.update!
      Spree::Adjustment.create!(
            amount: compute_amount(order),
            order: order,
            adjustable: order,
            source: self,
            mandatory: true,
            label: "#{Spree.t(:gift_card)}"
          )

      order.update!
    end

    # Calculate the amount to be used when creating an adjustment
    def compute_amount(calculable)
      self.calculator.compute(calculable, self)
    end

    def debit(amount, order)
      raise 'Cannot debit gift card by amount greater than current value.' if (self.current_value - amount.to_f.abs) < 0
      transaction = self.transactions.build
      transaction.amount = amount
      transaction.order  = order
      self.current_value = self.current_value - amount.abs
      self.save
    end

    def price
      self.line_item ? self.line_item.price * self.line_item.quantity : self.variant.price
    end

    def order_activatable?(order)
      order &&
      created_at < order.created_at &&
      current_value > 0 &&
      !UNACTIVATABLE_ORDER_STATES.include?(order.state)
    end

    private

    def generate_code
      until self.code.present? && self.class.where(code: self.code).count == 0
        # Random, unguessable number as a base20 string
        raw_string = SecureRandom.random_number( 2**80 ).to_s( 20 ).reverse # e.g. "3ecg4f2f3d2ei0236gi"
        long_code = raw_string.tr( '0123456789abcdefghij', '234679QWERTYUPADFGHX' ) # e.g. "6AUF7D4D6P4AH246QFH"
        short_code = long_code[0..3] + '-' + long_code[4..7] + '-' + long_code[8..11] # e.g. "6AUF-7D4D-6P4A"
        self.code = short_code
      end
    end

    def set_calculator
      self.calculator = Spree::Calculator::GiftCard.new
    end

    def set_values
      self.current_value  = self.variant.try(:price)
      self.original_value = self.variant.try(:price)
    end

  end
end
