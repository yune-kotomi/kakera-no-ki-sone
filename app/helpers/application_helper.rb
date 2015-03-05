module ApplicationHelper
  def link_to_user(label = nil, user = @login_user, options = {})
    label = user.nickname if label.nil?
    link_to label, options.update(
      :controller => :users,
      :action => :show,
      :domain_name => user.domain_name,
      :screen_name => user.screen_name
    )
  end
end
