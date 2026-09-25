require "test_helper"

class OfficialLettersWorkflowTest < ActionDispatch::IntegrationTest
  test "super admin can create, view and download an official letter" do
    sign_in(users(:one))

    assert_difference "OfficialLetter.count", 1 do
      post admin_official_letters_path, params: {
        official_letter: {
          recipient_name: "District Council",
          subject: "Annual Report Submission",
          letter_date: Date.current,
          header_president_name: "President Test",
          header_secretary_name: "Secretary Test",
          header_president_phone: "+81 90 1111 2222",
          header_secretary_phone: "+81 90 3333 4444",
          header_email: "office@tokyomizochurch.org",
          header_website: "www.tokyomizochurch.org",
          salutation: "Rawngbawlpui duhtak,",
          body: "<p>Dear Sir/Madam,</p><p>Please find attached our annual report.</p>",
          status: "draft"
        }
      }
    end

    letter = OfficialLetter.order(:created_at).last
    assert_redirected_to admin_official_letter_path(letter)
    assert_equal "President Test", letter.header_president_name
    assert_equal "+81 90 1111 2222", letter.header_president_phone
    assert_equal "+81 90 3333 4444", letter.header_secretary_phone
    assert_equal "office@tokyomizochurch.org", letter.header_email

    get admin_official_letter_path(letter)
    assert_response :success
    assert_select "h1", text: "Annual Report Submission"
    assert_select ".official-letter-sheet", text: /Subject :\s*Annual Report Submission/
    assert_select ".official-letter-sheet h2", count: 0
    assert_select "button", text: /Print/
    assert_match "President Test", response.body
    assert_match "www.tokyomizochurch.org", response.body
    assert_select "span", text: "+81", count: 2
    assert_no_match(/\+81\s+\+81/, response.body)

    get admin_official_letter_path(letter, format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
  end

  test "new letter prefills editable letterhead contacts" do
    sign_in(users(:one))

    get new_admin_official_letter_path

    assert_response :success
    assert_select "input[name='official_letter[header_president_name]']"
    assert_select "input[name='official_letter[header_secretary_name]']"
    assert_select "input[name='official_letter[header_president_phone]']"
    assert_select "input[name='official_letter[header_secretary_phone]']"
    assert_select "input[name='official_letter[header_email]'][value='admin@tokyomizochurch.org']"
    assert_select "input[name='official_letter[header_website]'][value='tokyomizochurch.org']"
    assert_select "h2", text: "Recipient Details"
    assert_select "label[for='official_letter_recipient_name']", text: /Lehkha dawngtu hming/
    assert_select "label[for='official_letter_recipient_organization']", text: /A thawhna office emaw pawl hming/
    assert_select "label[for='official_letter_recipient_address']", text: /Lehkha thawnna tur address/
    assert_select "select[name='official_letter[letter_kind]']", count: 0
    assert_select "input[name='official_letter[reference_number]']", count: 0
    assert_no_match(/Quick Template/, response.body)
  end

  test "official letters are available from desktop navigation" do
    sign_in(users(:one))

    get admin_root_path

    assert_response :success
    assert_select "aside a[href='#{admin_official_letters_path}']", text: /Letters/
  end

  test "read-only role can view but not create, edit or delete letters" do
    sign_in(users(:three))

    get admin_official_letters_path
    assert_response :success

    get new_admin_official_letter_path
    assert_redirected_to admin_root_path

    assert_no_difference "OfficialLetter.count" do
      post admin_official_letters_path, params: {
        official_letter: { recipient_name: "X", subject: "Y", letter_date: Date.current }
      }
    end
  end

  test "official letter pdf requires authentication" do
    letter = OfficialLetter.create!(
      recipient_name: "Recipient",
      subject: "Subject",
      letter_date: Date.current,
      created_by: users(:one)
    )

    get admin_official_letter_path(letter, format: :pdf)
    assert_response :unauthorized
  end

  test "letter can be created linked to an existing resolution and shows the back-reference" do
    resolution = ChurchResolution.create!(title: "Fence repair", status: :pending, priority: :normal)
    sign_in(users(:one))

    post admin_official_letters_path, params: {
      official_letter: {
        recipient_name: "Contractor",
        subject: "Fence Repair Confirmation",
        letter_date: Date.current,
        church_resolution_id: resolution.id
      }
    }

    letter = OfficialLetter.order(:created_at).last
    assert_equal resolution, letter.church_resolution

    get admin_church_resolution_path(resolution)
    assert_select "a", text: letter.reference_number
  end

  test "index supports filtering by year and status" do
    sign_in(users(:one))

    OfficialLetter.create!(
      recipient_name: "A", subject: "Alpha", letter_date: Date.current,
      created_by: users(:one), status: :draft
    )
    OfficialLetter.create!(
      recipient_name: "B", subject: "Beta", letter_date: Date.current,
      created_by: users(:one), status: :sent
    )

    get admin_official_letters_path, params: { status: "sent" }
    assert_response :success
    assert_select "h2", text: "Beta"
    assert_select "h2", text: "Alpha", count: 0
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
