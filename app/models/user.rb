class User < ActiveRecord::Base
  include RailsSettings::Extend
  ratyrate_rater
  audited
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable, :recoverable, :rememberable,
  :trackable, :validatable
  # , :confirmable
  # associations
  has_many :books
  has_many :reviews, dependent: :destroy
  # acts_as_x
  acts_as_follower
  #scopes
  scope :blocked, -> { where(is_blocked: true)  }
   def block
     self.is_blocked=true
     self.save
   end
   def unblock
     self.is_blocked=false
     self.save
   end
   def name
     username || email
   end
   def unsubscribed_books
     return [] if self.settings.unsubscribed_books.nil? || self.settings.unsubscribed_books.empty?
     self.settings.unsubscribed_books.map { |id|  Book.find_by_id(id)}
   end
   def subscribed_books
     following_books-unsubscribed_books
   end
   def is_subscribed?(book)
     subscribed_books.include? book
   end
   def send_digest_notification
    books=self.subscribed_books
    reviews=books.collect(&:reviews)
    rates=books.collect{|book| book.rates("title")}
    reviews=reviews.select { |review| review.where('created_at <= ?',1.day.ago) }.flatten
    rates=rates.select { |rate| rate.where('created_at <= ?',1.day.ago) }.flatten
    if reviews.present?
      Notifications.review_digest_notification(reviews,self).deliver
    end
    if rates.present?
    # if true
      Notifications.rate_digest_notification(rates,self).deliver
    end
  end
  def self.send_digest_notification
   users=User.with_settings_for('email_type')
   users=users.select { |user| user.settings.email_type =='digest' }
   users.each do |user|
     user.send_digest_notification
   end
  end
end
