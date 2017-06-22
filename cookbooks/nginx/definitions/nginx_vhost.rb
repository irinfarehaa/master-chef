define :nginx_vhost, {
  :options => {}
} do
  nginx_vhost_params = params

  config, vhost_sym = extract_config_with_last nginx_vhost_params[:name]

  nginx_listen = "listen #{config[:listen]}"
  nginx_listen += " default" if config[:default]
  nginx_listen += ";\n"
  nginx_listen += "server_name #{config[:virtual_host]};\n" if config[:virtual_host]
  basic_auth = config[:basic_auth]

  if config[:deny]
    config[:deny].each do |d|
      nginx_listen += "deny #{d};\n"
    end
  end

  ssl = config[:ssl]

  if ssl
    ssl_sym = ssl[:ssl_sym] || vhost_sym;

    nginx_listen += "ssl on;\n";
    nginx_listen += "ssl_certificate /etc/nginx/#{ssl_sym}.crt;\n"
    nginx_listen += "ssl_certificate_key /etc/nginx/#{ssl_sym}.key;\n"

    unless ssl[:ssl_sym]
      %w{key crt}.each do |ext|
        template "/etc/nginx/#{vhost_sym}.#{ext}" do
          cookbook ssl[:cookbook]
          source ssl[ext.to_sym]
          mode '0600'
          owner "www-data"
        end
      end
    end

  end

  auth = ""
  if basic_auth
    auth += "\n"
    auth += "auth_basic \"#{basic_auth[:realm]}\";\n"

    if basic_auth[:file]
      auth += "auth_basic_user_file /etc/nginx/#{basic_auth[:file]}.passwd;\n"

      template "/etc/nginx/#{basic_auth[:file]}.passwd" do
        cookbook basic_auth[:cookbook]
        source "#{basic_auth[:file]}.passwd.erb"
        mode '0644'
        notifies :reload, "service[nginx]"
      end
    end

    if basic_auth[:users]
      auth += "auth_basic_user_file /etc/nginx/#{vhost_sym}.passwd;\n"

      passwd = ""
      basic_auth[:users].each do |k, v|
        passwd += "#{k}:#{v.crypt('salt')}\n"
      end

      file "/etc/nginx/#{vhost_sym}.passwd" do
        content passwd
        mode '0644'
        notifies :reload, "service[nginx]"
      end

    end

  end

  nginx_listen += config[:extended_listen] if config[:extended_listen]

  template "/etc/nginx/sites-enabled/#{vhost_sym.to_s}.conf" do
    source nginx_vhost_params[:options][:source] || "#{vhost_sym.to_s}.conf.erb"
    cookbook nginx_vhost_params[:options][:cookbook].to_s if nginx_vhost_params[:options][:cookbook]
    mode '0644'
    variables({
      :listen => nginx_listen + auth,
      :listen_no_auth => nginx_listen,
      :config => config,
      :server_tokens => 'Off',
      :vhost_sym => vhost_sym,
    }.merge(nginx_vhost_params[:options]).merge(config[:options] || {}))
    notifies :reload, "service[nginx]"
  end

end
