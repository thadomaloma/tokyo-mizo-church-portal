require "test_helper"

class ChurchResolutionsWorkflowTest < ActionDispatch::IntegrationTest
  test "super admin can create a resolution, download its pdf and delete it" do
    sign_in(users(:one))

    assert_difference "ChurchResolution.count", 1 do
      post admin_church_resolutions_path, params: {
        church_resolution: { title: "Repaint the hall", status: "pending", priority: "normal" }
      }
    end

    resolution = ChurchResolution.order(:created_at).last
    assert_match(/\ARES-\d{4}-\d{3}\z/, resolution.number)
    assert_redirected_to admin_church_resolutions_path

    get admin_church_resolution_path(resolution, format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.media_type

    assert_difference "ChurchResolution.count", -1 do
      delete admin_church_resolution_path(resolution)
    end
  end

  test "read-only role can view but not create, edit or delete resolutions" do
    sign_in(users(:three))

    get admin_church_resolutions_path
    assert_response :success

    get new_admin_church_resolution_path
    assert_redirected_to admin_root_path

    assert_no_difference "ChurchResolution.count" do
      post admin_church_resolutions_path, params: { church_resolution: { title: "Nope" } }
    end
  end

  test "resolution pdf requires authentication" do
    resolution = ChurchResolution.create!(title: "Needs auth", status: :pending, priority: :normal)

    get admin_church_resolution_path(resolution, format: :pdf)
    assert_response :unauthorized
  end

  test "new resolution preselects the meeting minute when linked from a minute" do
    minute = meeting_minutes(:one)
    sign_in(users(:one))

    get new_admin_church_resolution_path(meeting_minute_id: minute.id)
    assert_response :success
    assert_select "select#church_resolution_meeting_minute_id option[selected][value='#{minute.id}']"
  end

  test "index supports filtering by status" do
    sign_in(users(:one))

    ChurchResolution.create!(title: "Pending item", status: :pending, priority: :normal)
    ChurchResolution.create!(title: "Done item", status: :completed, priority: :normal)

    get admin_church_resolutions_path, params: { status: "completed" }
    assert_response :success
    assert_select "h2", text: "Done item"
    assert_select "h2", text: "Pending item", count: 0
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
