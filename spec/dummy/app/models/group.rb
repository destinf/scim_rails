class Group < ApplicationRecord
  has_many :users
  belongs_to :company

  validates \
  :name,
  uniqueness: {
    case_insensitive: true
  }

  def active?
    archived_at.blank?
  end

  def archived?
    archived_at.present?
  end

  def archive!
    write_attribute(:archived_at, Time.now)
    save!
  end

  def unarchived?
  a rchived_at.blank?
  end

  def unarchive!
    write_attribute(:archived_at, nil)
    save!
  end
end
