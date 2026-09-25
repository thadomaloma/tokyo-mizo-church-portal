require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "visible_for excludes notifications created by the same user" do
    actor = users(:one)

    assert_not_includes Notification.visible_for(actor), notifications(:one)
    assert_includes Notification.visible_for(actor), notifications(:two)
  end

  test "unread_for excludes notifications created by the same user" do
    actor = users(:one)

    assert_not_includes Notification.unread_for(actor), notifications(:one)
    assert_includes Notification.unread_for(actor), notifications(:two)
  end

  test "unread_for clears after all visible notifications are read" do
    user = users(:one)

    Notification.visible_for(user).find_each do |notification|
      NotificationRead.find_or_create_by!(
        notification: notification,
        user: user
      )
    end

    assert_empty Notification.unread_for(user)
  end

  test "visible_for includes notifications whose actor was removed" do
    notification = notifications(:two)
    notification.update_column(:actor_id, nil)

    assert_includes Notification.visible_for(users(:one)), notification
  end

  test "link must be an internal path" do
    notification = Notification.new(
      actor: users(:one),
      title: "Test",
      message: "Test notification",
      notification_type: "member"
    )

    notification.link = "https://example.com"
    assert_not notification.valid?
    assert_includes notification.errors[:link], "must be an internal path"

    notification.link = "/admin/reports"
    assert notification.valid?
  end

  test "link rejects backslashes that browsers may normalize as an external redirect" do
    notification = Notification.new(
      actor: users(:one),
      title: "Test",
      message: "Test notification",
      notification_type: "member",
      link: "/\\example.com"
    )

    assert_not notification.valid?
    assert_includes notification.errors[:link], "must be an internal path"
  end

  test "read_by is safe for a missing user" do
    assert_not notifications(:one).read_by?(nil)
  end

  test "finance notification is visible only to users with access to its unit" do
    user = users(:three)
    unit = finance_units(:thalai)
    notification = Notification.create!(
      actor: users(:two),
      finance_unit: unit,
      title: "Thalai Finance",
      message: "New Thalai entry",
      notification_type: "finance",
      link: "/admin/finance_transactions?finance_unit_id=#{unit.id}"
    )

    assert_not_includes Notification.visible_for(user), notification

    FinanceUnitMembership.create!(finance_unit: unit, user: user, role: "viewer")

    assert_includes Notification.visible_for(user), notification
  end

  test "assigned department treasurer can create a scoped finance notification" do
    actor = users(:three)
    unit = finance_units(:naupang)
    FinanceUnitMembership.create!(finance_unit: unit, user: actor, role: "treasurer")

    assert_difference -> { Notification.where(finance_unit: unit).count }, 1 do
      NotificationCreator.call(
        actor: actor,
        finance_unit: unit,
        title: "New Finance Entry",
        message: "Department entry created",
        notification_type: "finance",
        link: "/admin/finance_transactions?finance_unit_id=#{unit.id}"
      )
    end
  end

  test "global finance role cannot publish to an unassigned department" do
    actor = User.create!(
      name: "Main Treasurer",
      email: "main-treasurer-notification@example.com",
      password: "secure-password",
      role: :treasurer
    )

    notification = NotificationCreator.call(
      actor: actor,
      finance_unit: finance_units(:thalai),
      title: "Restricted unit",
      message: "Must not publish",
      notification_type: "finance",
      link: "/admin/finance_transactions"
    )

    assert_nil notification
  end

  test "recipients excludes the actor for a general notification" do
    notification = Notification.create!(
      actor: users(:one),
      title: "General",
      message: "General update",
      notification_type: "member"
    )

    assert_not_includes notification.recipients, users(:one)
    assert_includes notification.recipients, users(:two)
  end

  test "recipients excludes inactive users" do
    inactive = User.create!(name: "Inactive Member", email: "inactive-recipient@example.com", password: "secure-password", role: :executive_member, active: false)

    notification = Notification.create!(
      actor: users(:one),
      title: "General",
      message: "General update",
      notification_type: "member"
    )

    assert_not_includes notification.recipients, inactive
  end

  test "recipients for a finance notification match can_view_finance_unit? exactly" do
    unit = finance_units(:thalai)
    member_with_access = users(:three)
    FinanceUnitMembership.create!(finance_unit: unit, user: member_with_access, role: "viewer")

    notification = Notification.create!(
      actor: users(:two),
      finance_unit: unit,
      title: "Thalai Finance",
      message: "New Thalai entry",
      notification_type: "finance"
    )

    assert_includes notification.recipients, member_with_access
    assert_includes notification.recipients, users(:one), "super admins can always view every finance unit"
    assert_not_includes notification.recipients, users(:two), "the actor must never be a recipient"
  end

  test "NotificationCreator enqueues a push delivery job for the created notification" do
    actor = users(:one)

    assert_enqueued_with(job: PushDeliveryJob) do
      NotificationCreator.call(
        actor: actor,
        title: "General",
        message: "General update",
        notification_type: "member",
        link: "/admin/users"
      )
    end
  end

  test "NotificationCreator does not enqueue a push job when the actor is not authorized to publish" do
    unauthorized_actor = users(:three)

    assert_no_enqueued_jobs only: PushDeliveryJob do
      NotificationCreator.call(
        actor: unauthorized_actor,
        title: "General",
        message: "General update",
        notification_type: "member",
        link: "/admin/users"
      )
    end
  end
end
