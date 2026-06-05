module UsersHelper
  def role_label(user)
    {
      "president" => "President",
      "vice_president" => "Vice President",
      "secretary" => "Secretary",
      "assistant_secretary" => "Assistant Secretary",
      "treasurer" => "Treasurer",
      "finance_secretary" => "Finance Secretary",
      "journal_secretary" => "Journal Secretary",
      "executive_member" => "Executive Member",
      "pastor" => "Pastor",
      "adviser" => "Adviser"
    }[user.role]
  end
end
