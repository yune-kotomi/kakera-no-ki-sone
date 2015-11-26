module ApplicationHelper
  def link_to_user(label = nil, user = @login_user, options = {}, html_options = {})
    label = user.nickname if label.nil?
    link_to label, options.update(
      :controller => :users,
      :action => :show,
      :domain_name => user.domain_name,
      :screen_name => user.screen_name
    ), html_options
  end

  def link_to_profile_edit(label = 'プロフィール編集', html_options = {})
    link_to label, Sone::Application.config.authentication.edit, html_options
  end
end
