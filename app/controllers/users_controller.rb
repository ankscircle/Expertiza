class UsersController < ApplicationController
  auto_complete_for :user, :name
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  def _profile
    @uid = params[:link]
  end
  def index
    if (current_user_role? == "Student")
      redirect_to(:action => AuthHelper::get_home_action(session[:user]), :controller => AuthHelper::get_home_controller(session[:user]))
    else
      list
      render :action => 'list'
    end
  end

  def self.participants_in(assignment_id)
    users = Array.new
    participants = AssignmentParticipant.find_by_parent_id(assignment_id)
    participants.each{
        |participant|
      users << User.find(participant.user_id)
    }
  end

  def auto_complete_for_user_name
    user = session[:user]
    role = Role.find(user.role_id)
    @users = User.find(:all, :conditions => ['name LIKE ? and (role_id in (?) or id = ?)', "#{params[:user][:name]}%",role.get_available_roles, user.id])
    render :inline => "<%= auto_complete_result @users, 'name' %>", :layout => false
  end
  def get_Team_Names
    @teamNamesHashCollected = Hash.new
    @userIDForTeam.each do  |member|
      if !@teamParticipation[member].nil?
        @teamParticipation[member].each { |teamMember|
          @pleaseSave = (Team.find((teamMember).team_id) ).name
          @teamNamesHashCollected[(teamMember).team_id] = @pleaseSave
        }
      end
    end
    @teamNamesHashCollected
  end

  def get_Team_Member_No(user_id)
    final_users = Hash.new
    team_user = []
    @teamParticipation[user_id].each do |member|
      team_user = TeamsUser.find_by_team_id(member)
      team_user.each do |user_s.id|
        if !(final_users[].include? user_s.id)
          (final_users) << user_s.id
          Team.find
        end
      end

    end
   final_users
  end
  #for displaying the list of users

  def list
    user = session[:user]
    role = Role.find(user.role_id)
    all_users = User.find(:all, :order => 'name', :conditions => ['(role_id in (?) or id = ?) and parent_id = ?', role.get_available_roles, user.id,user.id])

    @doubleArry = User.get_users_created_by_id(user)
    @teamParticipation,@userNamesForTeam,@userIDForTeam = User.get_team_participation(user)

    get_Team_Names
    Rails.logger.info("Radhika & Deepali ######################")
    Rails.logger.info("PARAMS: #{params.inspect}")
    #Rails.logger.info("#{@doubleArry}}")

    letter = params[:letter]
    session[:letter] = letter
    if letter == nil
      letter = ""
    end
    logger.info "#{letter}"
    @letters = Array.new

    @per_page = 1

    # Check if the "Show" button for pagination is clicked
    # If yes, set @per_page to the value of the selection dropdown
    # Else, if the request is from one of the letter links on the top
    # set @per_page to 1 (25 names per page).
    # Else, set @per_page to the :num_users param passed in from
    # the will_paginate method from the 'pagination' partial.
    if params[:paginate_show]
      if params[:num_users].to_i < 1
        params[:num_users] = 25
      end
    end
    if params[:paginate_show]
      @per_page = params[:num_users]
    elsif params[:from_letter]
      @per_page = 1
    else
      @per_page = params[:num_users]
    end

    # Get the users list to show on current page
    @users = paginate_list(role, user.id, letter)

    all_users.each {
        | userObj |
      first = userObj.name[0,1].downcase
      if not @letters.include?(first)
        @letters << first
      end
    }
    #This is for select all

    @uid = params[:link]
    if @uid != nil
      @result_array =  params[:link]
      render :action => '_profile', :id =>@result_array
    end
  end

  def show_selection
    @user = User.find_by_name(params[:user][:name])
    if @user != nil
      retrieve_teams_worked_with
      get_role
      get_assignments
      get_courses

      if @role.parent_id == nil || @role.parent_id < (session[:user]).role_id || @user.id == (session[:user]).id
        render :action => 'show'
      else
        flash[:note] = 'The specified user is not available for editing.'
        redirect_to :action => 'list'
      end
    else
      flash[:note] = params[:user][:name]+' does not exist.'
      redirect_to :action => 'list'
    end
  end

  def show
    if (params[:id].nil?) || ((current_user_role? == "Student") &&  (session[:user].id != params[:id].to_i))
      redirect_to(:action => AuthHelper::get_home_action(session[:user]), :controller => AuthHelper::get_home_controller(session[:user]))
    else
      @user = User.find(params[:id])
      get_role
      get_assignments
      get_courses
      retrieve_teams_worked_with
    end
  end

  def new
    @user = User.new
    foreign
  end

  def create
    # if the user name already exists, register the user by email address
    check = User.find_by_name(params[:user][:name])
    if check != nil
      params[:user][:name] = params[:user][:email]
    end

    @user = User.new(params[:user])
    # record the person who created this new user
    @user.parent_id = (session[:user]).id

    if @user.save
      #Instructor and Administrator users need to have a default set for their notifications
      # the creation of an AssignmentQuestionnaire object with only the User ID field populated
      # ensures that these users have a default value of 15% for notifications.
      #TAs and Students do not need a default. TAs inherit the default from the instructor,
      # Students do not have any checks for this information.
      if @user.role.name == "Instructor" or @user.role.name == "Administrator"
        AssignmentQuestionnaire.create(:user_id => @user.id)
      end
      flash[:notice] = 'User was successfully created.'
      redirect_to :action => 'list'
    else
      foreign
      render :action => 'new'
    end
  end

  def edit
    @user = User.find(params[:id])
    get_role
    foreign
  end

  def update
    @user = User.find(params[:id])

    if @user.update_attributes(params[:user])
      flash[:notice] = 'User was successfully updated.'
      redirect_to :action => 'show', :id => @user
    else
      foreign
      render :action => 'edit'
    end
  end

  def updateAll
    for item in params[:userids]
     @user = User.find(item)
      if @user

      #if @user.update_attributes(@user.role_id => params[:user][:role_id])
      if (@user.role_id == 1 && params[:user][:role_id]=="true")
      @user.role_id = 5
      @user.save!
      end
      @user.email_on_review =  params[:user][:email_on_review]
      @user.save!
      @user.leaderboard_privacy =  params[:user][:leaderboard_privacy]
      @user.save!
      @user.email_on_review_of_review =  params[:user][:email_on_review_of_review]
      @user.save!
      @user.email_on_submission =  params[:user][:email_on_submission]
      @user.save!
      flash[:note] = 'User was successfully updated.'
  end
    end
    redirect_to :action => 'list'
  end



  def destroy
    begin
      user = User.find(params[:id])
      AssignmentParticipant.find_all_by_user_id(user.id).each{|participant| participant.delete}
      TeamsUser.find_all_by_user_id(user.id).each{|teamuser| teamuser.delete}
      AssignmentQuestionnaire.find_all_by_user_id(user.id).each{|aq| aq.destroy}
      user.destroy
    rescue
      flash[:error] = $!
    end

    redirect_to :action => 'list'
  end

  def keys
    if (params[:id].nil?) || ((current_user_role? == "Student") &&  (session[:user].id != params[:id].to_i))
      redirect_to(:action => AuthHelper::get_home_action(session[:user]), :controller => AuthHelper::get_home_controller(session[:user]))
    else
      @user = User.find(params[:id])
      @private_key = @user.generate_keys
    end
  end

  protected

  def foreign
    role = Role.find((session[:user]).role_id)
    @all_roles = Role.find(:all, :conditions => ['id in (?) or id = ?',role.get_available_roles,role.id])
  end

  private

  def get_role
    if @user && @user.role_id
      @role = Role.find(@user.role_id)
    elsif @user
      @role = Role.new(:id => nil, :name => '(none)')
    end
  end
  def get_courses
    courseTuples = Participant.find(:all,:conditions => ['user_id = ? and type = ?',@user.id,'CourseParticipant'])
    courseTuples.each do |course|
      if @userCourses.nil?
        @userCourses = Course.find(course.parent_id).name
      end
    end
    @userCourses
  end

  def retrieve_teams_worked_with
    @TeamMemberHash = Hash.new
    @courseNameList = Hash.new
    teamIDList = []
    @courseIDList = []
    @assignmentIDList = []
    assignmentTuples = Participant.find(:all,:conditions => ['user_id = ? and type = ?',@user.id,'AssignmentParticipant'])
    courseTuples = Participant.find(:all,:conditions => ['user_id = ? and type = ?',@user.id,'CourseParticipant'])

    teamTuples = TeamsUser.find(:all,:conditions => ['user_id = ?',@user.id])
    teamTuples.each do |teamID|
      teamIDList << teamID.team_id
    end

    assignmentTuples.each do |assignmentID|
      @assignmentIDList << assignmentID.parent_id
    end
    @assignmentIDList.each do |assignmentsPull|
         @courseIDList << (Assignment.find_by_id(assignmentsPull)).course_id
    end

   @courseIDList.each do |courseID|
      @TeamMemberHash[courseID] = []
      @courseNameList[courseID] = (Course.find(courseID)).name
      assignmentsForThisCourse = Assignment.find(:all,:conditions => ['course_id = ?',courseID])
      assignmentsForThisCourse.each do |assignTeams|
        teamIDFromAssign = []
        teamsForAssignment  = Team.find(:all,:conditions => ['parent_id = ?',assignTeams.id])
        teamsForAssignment.each do |assignMembers|
            teamIDFromAssign << assignMembers.id
        end
        teamForPresentUser = teamIDList & teamIDFromAssign

        teamForPresentUser.each do |teamTuple|
          memberTuples = TeamsUser.find(:all,:conditions => ['team_id = ?',teamTuple])
          memberTuples.each do |member|

            if !(@TeamMemberHash[courseID].include? member) && member.user_id != @user.id
              @TeamMemberHash[courseID] << member
            end
          end
        end
      end
 end

 @TeamMemberHash
 end
  def get_assignments
    assignmentTuples = Participant.find(:all,:conditions => ['user_id = ? and type = ?',@user.id,'AssignmentParticipant'])
    assignmentTuples.each do |assignment|
      if @userAssignments.nil?
        @userAssignments =  Assignment.find(assignment.parent_id).name
      else
        @userAssignments = @userAssignments + ', ' +Assignment.find(assignment.parent_id).name

      end
    end
    @userAssignments
  end


  # For filtering the users list with proper search and pagination.
  def paginate_list(role, user_id, letter)
    # paginate_options = {"1" => 25, "2" => 50, "3" => 100}

    # If the above hash does not have a value for the key,
    # it means that we need to show all the users on the page
    #
    # Just a point to remember, when we use pagination, the
    # 'users' variable should be an object, not an array

    #The type of condition for the search depends on what the user has selected from the search_by dropdown
    condition = "(role_id in (?) or id = ?) and name like ? and parent_id like ?" #default used when clicking on letters
    search_filter = letter + '%'
    @search_by = params[:search_by]
    if @search_by == '1'  #search by user name
      condition = "(role_id in (?) or id = ?) and name like ? and parent_id like ?"
      search_filter = '%' + letter + '%'
    elsif @search_by == '2' # search by full name
      condition = "(role_id in (?) or id = ?) and fullname like ? and parent_id like ?"
      search_filter = '%' + letter + '%'
    elsif @search_by == '3' # search by email
      condition = "(role_id in (?) or id = ?) and email like ? and parent_id like ?"
      search_filter = '%' + letter + '%'
    end

    if (@per_page.nil?) #displaying all - no pagination
      users = User.paginate(:page => params[:page], :order => 'name', :per_page => 25, :conditions => [condition, role.get_available_roles, user_id, search_filter,user_id])
    else #some pagination is active - use the per_page
      users = User.paginate(:page => params[:page], :order => 'name', :per_page => @per_page, :conditions => [condition, role.get_available_roles, user_id, search_filter,user_id])
    end
    users
  end
end
