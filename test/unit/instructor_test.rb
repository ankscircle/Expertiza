require File.dirname(__FILE__) + '/../test_helper'

class InstructorTest < ActiveSupport::TestCase
  fixtures :users
  def test_list_all
    ins = Instructor.new(:email => "userapp@gmail.com", :name => "instructor_new",:fullname=>"New UserApp", :clear_password => "userapppass",:clear_password_confirmation=>"userapppass")
    ins.save!
    assert ins.valid?

  end
end