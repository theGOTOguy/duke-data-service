class Activity < ActiveRecord::Base
  include Kinded
  include Graphed
  after_create :create_graph_node
  after_save :logically_delete_graph_node
  after_destroy :delete_graph_node

  audited

  belongs_to :creator, class_name: 'User'

  validates :name, presence: true
  validates :creator_id, presence: true
  validate :valid_dates

  def valid_dates
    if  started_on && ended_on && started_on > ended_on
      self.errors.add :ended_on, ' must be >= started_on'
    end
  end
end