module UnRestorable
  extend ActiveSupport::Concern

  included do
    before_update :manage_deletion, if: :saved_change_to_is_deleted?
  end

  def manage_deletion
    if is_deleted?
      @child_job = ChildPurgationJob
    end
  end

  # ChildMinder method
  def purge_children(page)
    paginated_children(page).each do |child|
      child.current_transaction = current_transaction if child.class.include? JobTransactionable
      child.update(is_deleted: true, is_purged: true)
    end
  end
end
