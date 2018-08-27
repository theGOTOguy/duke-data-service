namespace :job_transaction do
  namespace :clean_up do
    desc 'Removes completed JobTransactions older than a month'
    task completed: :environment do
      if oldest = JobTransaction.oldest_completed_at
        months_ago = ((Time.now - oldest) / 1.month).floor
        if months_ago > 0
          months_ago.downto(1).each do |m|
            del_num = JobTransaction.delete_all_complete_jobs(created_before: Time.now - m.months)
            puts "Deleted #{del_num} JobTransactions for completed jobs from #{m} #{'month'.pluralize(m)} ago."
          end
        else
          puts "No completed JobTransactions older than 1 month found."
        end
      else
        puts "No completed JobTransactions found."
      end
    end

    desc 'Removes orphan JobTransactions older than a month'
    task orphans: :environment do
      if oldest = JobTransaction.oldest_orphan_created_at
        months_ago = ((Time.now - oldest) / 1.month).floor
        if months_ago > 0
          months_ago.downto(1).each do |m|
            del_num = JobTransaction.delete_all_orphans(created_before: Time.now - m.months)
            puts "Deleted #{del_num} orphan JobTransactions from #{m} #{'month'.pluralize(m)} ago."
          end
        else
          puts "No orphan JobTransactions older than 1 month found."
        end
      else
        puts "No orphan JobTransactions found."
      end
    end
  end
end