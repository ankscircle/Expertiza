require File.dirname(__FILE__) + '/../test_helper'

class UserTest < ActiveSupport::TestCase
  fixtures :users

  def test_new_user_creation  #We will check if a new user can be added successfully or not
    u = User.new(:email => "userapp@gmail.com", :name => "userapp", :clear_password => "userapppass",:clear_password_confirmation=>"userapppass")
    u.save!
    assert_equal "userapppass", u.clear_password
  end

  def test_new_user_with_blank_password_for_random_pass_generation   #We will check if a new user with blank password is assigned new random password
    u = User.new(:email => "user@app.com", :name => 'newguy')
    u.save!
    assert u.clear_password.present?
  end

  def test_user_for_uniqueness_of_name     #We will check if a new user when added should have unique name
    u = User.new(:email => "public@gmail.com", :name => "student1", :clear_password => "userapppass",:clear_password_confirmation=>"userapppass")
    assert !u.save
    assert_equal I18n.translate('activerecord.errors.messages')[:taken], u.errors.on(:name)
  end

  def test_to_return_correct_author_name    #When requested correct authorname should be returned
    u = User.new(:email => "userapp@gmail.com", :name => "userapp",:fullname=>"New UserApp", :clear_password => "userapppass",:clear_password_confirmation=>"userapppass")
    u.save!
    assert_equal "New UserApp", u.get_author_name
  end

  def test_user_to_find_by_login        #When requested correct authorname should be returned
    u = User.new(:email => "userapp@gmail.com", :name => "userapp",:fullname=>"New UserApp", :clear_password => "userapppass",:clear_password_confirmation=>"userapppass")
    u.save!
    assert_equal u, User.find_by_login("userapp@gmail.com")
  end

  #borrowed from unit test cases present in expertiza project- this was important to check
  # this test checks if the generate_keys function works properly/not
  def testing_user_key_generation
    u = User.new(:email => "userapp@gmail.com", :name => "userapp",:fullname=>"New UserApp", :clear_password => "userapppass",:clear_password_confirmation=>"userapppass")
    u.save!
    user = users(:student1)
    privatekeyforuser = user.generate_keys
    assert_not_nil privatekeyforuser
    assert_not_nil user.digital_certificate

    hash_data_user = Digest::SHA1.digest(Time.now.utc.strftime("%Y-%m-%d %H:%M:%S"))
    clear_text_user = decrypt(hash_data_user, privatekeyforuser, user.digital_certificate)
    assert_equal hash_data_user, clear_text_user

    # try decrypting a signature made using an old private key
    user.generate_keys
    clear_text_user = decrypt(hash_data_user, privatekeyforuser, user.digital_certificate)
    assert_not_equal hash_data_user, clear_text_user

  end
  #borrowed from unit test cases present in expertiza project- this was important to check
  def decrypt(hash_data, private_key, digital_certificate)
    private_key2 = OpenSSL::PKey::RSA.new(private_key)
    cipher_text = Base64.encode64(private_key2.private_encrypt(hash_data))
    cert = OpenSSL::X509::Certificate.new(digital_certificate)
    public_key1 = cert.public_key
    public_key = OpenSSL::PKey::RSA.new(public_key1)
    begin
      clear_text = public_key.public_decrypt(Base64.decode64(cipher_text))
    rescue
      clear_text = ''
    end

    clear_text
  end

  def test_emails_can_be_duplicated     #Check if the email can be duplicated
    existing_email = users(:student1).email
    u = User.new(:email => existing_email, :name => 'newappuser')
    assert u.valid?, "User should be valid with a duplicate email"
  end


  def test_check_welcome_email       #test if welcome email is sent properly
    user = User.new
    user.name = "newappuser"
    user.fullname = "Newapp User"
    user.clear_password = "newappuser"
    user.clear_password_confirmation = "newappuser"
    user.email = "test@gmail.com"
    user.role_id = "1"
    user.save! # an exception is thrown if the user is invalid

    email = user.email_welcome
    assert !ActionMailer::Base.deliveries.empty?         # Checks if the mail has been queued in the delivery queue

    assert_equal [user.email], email.to                  # Checks if the mail is being sent to proper user
    assert_equal "Your Expertiza password has been created", email.subject             # Checks if the mail subject is the same

  end

  def test_email_validation           #Test if the email address is entered correctly with proper format
    user = User.new
    user.name = "newappuser"
    user.fullname = "Newapp User"
    user.clear_password = "newappuser"
    user.clear_password_confirmation = "newappuser"
    user.email = "testgmail.com"
    user.role_id = "1"
    assert !user.save # an exception is thrown if the user is invalid
    assert_equal ["should look like an email address.", "is invalid"], user.errors.on(:email)

  end

  def test_try_to_create_user_with_invalid_name_assert_false  #creating users with invalid name should fail
    user = User.new(:name =>"")
    assert !user.valid?
    assert user.errors.invalid?(:name)
  end
  def test_try_to_update_user_with_invalid_name_assert_false      #updating users with invalid name should fail
    user = User.find_by_login('student2')
    user.name = "";
    assert !user.valid?
  end

  def test_email_cannot_be_blank     #creating user with blank email should fail
    user = User.new
    user.name = "newappuser"
    user.fullname = "Newapp User"
    user.clear_password = "newappuser"
    user.clear_password_confirmation = "newappuser"
    user.email = ""      #we gave email field as blank to check  the validation
    user.role_id = "1"
    assert !user.save # an exception is thrown if the user is invalid
    assert_equal ["is too short (minimum is 6 characters)",
                  "should look like an email address.",
                  "can't be blank; use anything@mailinator.com for test users"], user.errors.on(:email)
  end

end
