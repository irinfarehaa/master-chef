
define :incremental_template, {
  :header => "",
  :header_if_block => "",
  :footer => "",
  :footer_if_block => "",
  :owner => nil,
  :mode => nil,
  :notifies => nil,
  :only_if => nil,
  :not_if => nil,
  :indentation => 0,
} do

  incremental_template_params = params

  template incremental_template_params[:name] do
    source "incremental_template.erb"
    cookbook "master_chef"
    mode incremental_template_params[:mode] if incremental_template_params[:mode]
    owner incremental_template_params[:owner] if incremental_template_params[:owner]
    variables({
      :header => incremental_template_params[:header],
      :header_if_block => incremental_template_params[:header_if_block],
      :footer => incremental_template_params[:footer],
      :footer_if_block => incremental_template_params[:footer_if_block],
      :blocks => [],
      :indentation => incremental_template_params[:indentation],
    })
    notifies *incremental_template_params[:notifies] if incremental_template_params[:notifies]
    only_if incremental_template_params[:only_if] if incremental_template_params[:only_if]
    not_if incremental_template_params[:not_if] if incremental_template_params[:not_if]
  end

end

define :incremental_template_part, {
  :target => nil,
  :source => nil,
  :cookbook => nil,
  :variables => {},
} do

  incremental_template_part_params = params

  raise "Please specify target with incremental_template_part" unless incremental_template_part_params[:target]
  raise "Please specify source with incremental_template_part" unless incremental_template_part_params[:source]

  this_template = template "#{incremental_template_part_params[:target]}_#{incremental_template_part_params[:name]}" do
    source incremental_template_part_params[:source]
    cookbook incremental_template_part_params[:cookbook] if incremental_template_part_params[:cookbook]
    variables incremental_template_part_params[:variables] if incremental_template_part_params[:variables]
    action :nothing
  end

  begin
    r = resources(:template => incremental_template_part_params[:target])
    r.variables[:blocks] << Proc.new do
      provider = Chef::Platform.provider_for_resource(this_template)
      begin
        provider.load_current_resource
        result = ""

        if Chef::Mixin::Template.const_defined? "TemplateContext"
          # new templating system
          context = Chef::Mixin::Template::TemplateContext.new(this_template.variables)
          template_location = provider.send(:content).template_location
          context[:node] = r.run_context
          result = context.render_template(template_location)
        else
          # old templating system
          provider.send(:render_with_context, provider.template_location) do |x|
            result = File.read(x.path)
          end
        end
      rescue
        Chef::Log.error($!)
        raise "Unable to process incremental_template #{incremental_template_part_params[:name]}: #{$!}"
      end
    end
  rescue Chef::Exceptions::ResourceNotFound
    raise "Resource target not found #{incremental_template_part_params[:target]}"
  end

end

define :incremental_template_content, {
  :target => nil,
  :content => nil,
} do

  incremental_template_content_params = params

  raise "Please specify target with incremental_template_content" unless incremental_template_content_params[:target]
  raise "Please specify content with incremental_template_content" unless incremental_template_content_params[:content]

  begin
    r = resources(:template => incremental_template_content_params[:target])
    r.variables[:blocks] << Proc.new {incremental_template_content_params[:content]}
  rescue Chef::Exceptions::ResourceNotFound
    raise "Resource target not found #{incremental_template_content_params[:target]}"
  end

end