class UsersController < ApplicationController
  before_action :signed_in_user,
          only: [:index, :edit, :update, :show]
  before_action :correct_user, only: [:show, :edit, :update]
  before_action :admin_user, only: :destroy
  layout 'signin', only: [:new, :forgot_password, :password_reset]

  def index
    drop_breadcrumb "系统设置"
    drop_breadcrumb "用户管理", users_path
    @users_grid = initialize_grid(User, per_page: 20,
                    name: 'user',
                    order: 'users.created_at',
                    order_direction: 'desc')

    @users = User.all
    respond_to do |format|  
      format.xls {   
        send_data(xls_content_for(@users),  
        :type => "text/excel;charset=gbk; header=present",  
        :filename => "Report_Users_#{Time.now.strftime("%Y%m%d")}.xls")  
      }
      format.html
    end

  end
  
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      sign_in @user
      @user.update_attribute(:last_ip, request.remote_ip)
      redirect_to root_path, :flash => { :notice=>"欢迎使用RA-TAB!" }
    else
      render 'new', :layout => 'signin'
    end
  end

  def show
  end

  def edit
    @user = User.find(params[:id])
    drop_breadcrumb "系统设置"
    drop_breadcrumb "个人资料", 'edit'
  end

  def update
    @user = User.find(params[:id])
    if @user.update_attributes(user_params)
      sign_in @user
      redirect_to edit_user_path(@user), :flash => { :notice=>"资料修改完成" }
    else
      drop_breadcrumb "系统设置"
      drop_breadcrumb "个人资料", edit_user_path(@user)
      render 'edit'
    end
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy
    flash[:success] = "#{@user.name} 被成功删除!"
    redirect_to users_url
  end
  
  def password
    drop_breadcrumb "系统设置"
    drop_breadcrumb "修改密码", 'password'
    @user = User.find(params[:id])
  end

  def change_password
    @user = User.find(params[:id])
    if @user.update_password(user_params)
      #sign_in @user
      redirect_to root_path, :flash => { :notice=>"密码修改成功" }
    else
      drop_breadcrumb "系统设置"
      drop_breadcrumb "修改密码", 'password'
      render 'password'
    end
  end

  def forgot_password
    @user = User.new
  end

  def send_password_reset_instructions
    user = User.find_by_email(params[:user][:email])
    p user
    if user
      user.password_reset_token = SecureRandom.urlsafe_base64
      user.password_expires_after = 24.hours.from_now
      user.save
      UserMailer.reset_password_email(user).deliver
      flash[:notice] = '密码重置邮件已发送，请检查邮箱收件箱'
      redirect_to root_path
    else
      @user = User.new
      # put the previous value back.
      @user.email = params[:user][:email]
      @user.errors[:email] = '不是注册用户'
      render 'forgot_password', :layout => 'signin'
    end
  end

  def password_reset
    token = params.first[0]
    @user = User.find_by_password_reset_token(token)

    if @user.nil?
      flash[:error] = '您还没有申请重置密码，或者您刚刚已经完成了密码重置'
      redirect_to root_path
      return
    end

    if @user.password_expires_after < DateTime.now
      clear_password_reset(@user)
      @user.save
      flash[:error] = '重置密码请求超过24小时，请重新请求重置密码'
      redirect_to forgot_password_users
    end
  end

  def new_password
    @user = User.find_by_email(params[:user][:email])

    if @user.update_attributes(user_params)
      clear_password_reset(@user)
      redirect_to root_path, :flash => { :notice=>"密码修改成功，请用新密码登陆" }
    else
      render 'password_reset', :layout => 'signin'
    end
  end

  private
    def user_params
      params.require(:user).permit(:name, :email, :phone,
                      :password, :password_confirmation, :current_password)
    end

    def correct_user
      @user = User.find(params[:id])
      redirect_to(root_path) unless current_user?(@user)
    end

    def admin_user
      redirect_to(root_path) unless current_user.admin?
    end

    def xls_content_for(objs)
      xls_report = StringIO.new
      book = Spreadsheet::Workbook.new
      sheet1 = book.create_worksheet :name => "设备采购明细"

      blue = Spreadsheet::Format.new color: :blue, weight: :bold, size: 10
      sheet1.row(0).default_format = blue

      sheet1.row(0).concat ['序号', '账号', '用户名',
                  '联系电话','角色', '注册日期',
                  '最后登录IP', '最后登录时间' ]
      count_row = 1
      objs.each do |obj|
        sheet1[count_row,0] = count_row
        sheet1[count_row,1] = obj.email
        sheet1[count_row,2] = obj.name
        sheet1[count_row,3] = obj.phone
        sheet1[count_row,4] = obj.role
        sheet1[count_row,5] = obj.created_at.strftime("%Y-%m-%d")
        sheet1[count_row,6] = obj.last_ip
        sheet1[count_row,7] = obj.updated_at.strftime("%Y-%m-%d %H:%M:%S")
        count_row += 1  
      end  

      book.write xls_report  
      xls_report.string  
    end

    def clear_password_reset(user)
      user.password_expires_after = nil
      user.password_reset_token = nil
      user.save
    end

end
