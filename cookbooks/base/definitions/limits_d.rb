
define :limits_d, {
  :user => nil,
  :limit => nil,
  :value => nil,
} do
  limits_d_params = params

  raise "Please specify user with limits_d" unless limits_d_params[:user]
  raise "Please specify limit with limits_d" unless limits_d_params[:limit]
  raise "Please specify value with limits_d" unless limits_d_params[:value]

  node.set[:user_limits][limits_d_params[:user]] = {} unless node.user_limits[limits_d_params[:user]]
  node.set[:user_limits][limits_d_params[:user]][limits_d_params[:limit]] = [node.user_limits[limits_d_params[:user]][limits_d_params[:limit]] || 0, limits_d_params[:value]].max

  template "/etc/security/limits.d/#{limits_d_params[:user]}.conf" do
    variables :user => limits_d_params[:user]
    source "limits_d.erb"
    cookbook "base"
  end

end