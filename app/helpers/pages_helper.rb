module PagesHelper

  def site_pages
    @site_pages ||= current_site.webpages.includes(:template, :last_editor)
  end

  def site_root_pages
    @site_root_pages ||= site_pages.roots.in_position
  end

  def site_nav_pages
    @site_nav_pages ||= site_root_pages.select(&:show_in_nav?)
  end

  def site_floating_root_pages
    @site_floating_root_pages ||= site_root_pages.select { |p| !p.show_in_nav? }
  end

  def current_page
    @current_page ||= begin
      if(
        controller_name == 'pages' ||
        ['editor','documents'].include?(controller_name)
      )
        p = params[:page_slug] || params[:slug]
        page = current_site.webpages.find_by_slug(p)
        nil if page.nil?
        page
      else
        nil
      end
    end
  end

  def verify_current_page
    not_found if current_page.nil?
  end

  def current_page_template
    @current_page_template ||= current_template.filename
  end

  def current_page_template_class
    slug = @current_page_template
    slug = "_#{slug}" if slug[0] =~ /[0-9]/
    slug
  end

  def current_page_parent
    @current_page_parent ||= begin
      if params[:parent]
        current_site.pages.find_by_slug(params[:parent])
      else
        current_page_ancestors.last
      end
    end
  end

  def current_page_ancestors
    @current_page_ancestors ||= current_page.ancestors
  end

  def has_ancestors?
    @has_ancestors ||= current_page && current_page_ancestors.size > 0
  end

  def current_page_children
    @current_page_children ||= begin
      current_page.children.in_position.includes(:template)
    end
  end

  def eligible_parents(page)
    @eligible_parents ||= begin
      templates = site_templates.select {
        |t| t.children.include?(page.template.slug)
      }
      site_pages.select { |p| templates.collect(&:id).include?(p.template_id) }
        .sort_by(&:title)
    end
  end

  def current_page_children_paginated
    @current_page_children_paginated ||= begin
      current_page_children.page(params[:page]).per(10)
    end
  end

  def current_page_children_filtered
    @current_page_children_filtered ||= begin
      pages = current_page_children
      if params[:template] && !['any'].include?(params[:template])
        template = site_templates.select { |t| t.slug == params[:template] }
          .first
        pages = pages.select { |p| p.template == template }
      end
      if params[:published] && ['published','draft'].include?(params[:published])
        pages = pages.select(&:"#{params[:published]}?")
      end
      pages
    end
  end

  def current_page_children_filtered_paginated
    @current_page_children_filtered_paginated ||= begin
      Kaminari.paginate_array(current_page_children_filtered)
        .page(params[:page]).per(10)
    end
  end

  def page_children_button(page)
    children = page.template.children.reject(&:blank?)
    templates = site_templates.select { |t| children.include?(t.slug) }
    if templates.size > 1
      path = builder_route([page], :show)
      link_to(
        'Pages',
        path,
        :class => "pages #{request.path == path ? 'active' : nil}"
      )
    elsif templates.size > 0
      path = builder_site_page_path(current_site, page)
      link_to(
        templates.first.title.pluralize,
        path,
        :class => "pages #{request.path == path ? 'active' : nil}"
      )
    else
      nil
    end
  end

  def current_page_breadcrumbs
    # slash separator between breadcrumbs
    sep = content_tag(:span, '/', :class => 'separator')
    # render the site url as the link to root pages
    o = link_to(
      current_site.url.blank? ? current_site.slug : current_site.url,
      builder_route([site_pages], :index)
    )
    # look for current pages and add each
    if current_page
      if has_ancestors?
        current_page_ancestors.each do |a|
          o += sep
          o += link_to(a.slug, builder_route([a], :show))
        end
      end
      o += sep
      if current_page.title.blank?
        o += link_to(
          "new #{current_template.title.downcase}",
          builder_route([current_page], :new)
        )
      else
        o += link_to(current_page.slug, builder_route([current_page], :show))
      end
    end
    o.html_safe
  end

  def home_page
    @home_page ||= current_site.home_page
  end

  def is_home_page?(page)
    page == home_page
  end

  def new_page_children_links(prefix = "New")
    @new_page_children_links ||= begin
      content_tag(:div, :class => 'new-buttons dropdown') do
        if template_children.size > 1
          o = link_to("New Page", '#', :class => 'new dropdown-trigger')
          o += content_tag(:ul) do
            o2 = ''
            template_children.select { |t| !t.maxed_out? }.each do |template|
              o2 += content_tag(
                :li,
                link_to(
                  template.title,
                  new_builder_site_page_path(
                    current_site,
                    :template => template.slug,
                    :parent => current_page.slug
                  )
                )
              )
            end
            o2.html_safe
          end
        elsif template_children.size > 0
          template = template_children.first
          link_to(
            "#{prefix} #{template.title}",
            new_builder_site_page_path(
              current_site,
              :template => template.slug,
              :parent => current_page.slug
            ),
            :class => 'new button'
          )
        end
      end
    end
  end

  def page_status(page)
    if page.published?
      content_tag(:a, 'Published', :class => 'published disabled')
    else
      content_tag(:a, 'Draft', :class => 'draft disabled')
    end
  end

  def page_quick_status(page)
    if page.published?
      content_tag(:a, '', :class => 'published disabled')
    else
      content_tag(:a, '', :class => 'draft disabled')
    end
  end

  def new_root_page_links
    new_pages = site_templates.not_maxed_out.can_be_root
    content_tag(:div, :class => 'new-buttons dropdown') do
      if new_pages.size > 1
        o = link_to("New Page", '#', :class => 'new button dropdown-trigger')
        o += content_tag(:ul) do
          o2 = ''
          new_pages.each do |template|
            o2 += content_tag(
              :li,
              link_to(
                template.title,
                new_builder_site_page_path(
                  current_site,
                  :template => template.slug
                )
              )
            )
          end
          o2.html_safe
        end
      elsif new_pages.size == 1
        template = new_pages.first
        link_to(
          "New #{template.title}",
          new_builder_site_page_path(
            current_site,
            :template => template.slug
          ),
          :class => 'new button'
        )
      end
    end
  end

  def page_status(page)
    if page.published
      content_tag(:span, :class => 'page-status published') do
        o = content_tag(:i, nil, :class => 'icon-checkmark-circle')
        o += content_tag(:span, 'Published')
      end
    else
      content_tag(:span, :class => 'page-status draft') do
        o = content_tag(:i, nil, :class => 'icon-notification')
        o += content_tag(:span, 'Draft')
      end
    end
  end

  def page_last_edited(page)
    date = page.updated_at.strftime("%h %d")
    if page.last_editor
      editor = " by #{content_tag(:span, page.last_editor.display_name)}"
    else
      editor = ''
    end
    content_tag(:span, :class => 'last-edited') do
      "Last edited #{content_tag(:span, date)}#{editor}".html_safe
    end
  end

  def page_publish_filters
    o = ''
    ['all', 'published', 'drafts'].each do |link|
      p = link.singularize
      t = params[:template]
      if current_page
        path = builder_site_page_path(
          current_site, current_page, :published => p, :template => t
        )
      elsif current_template
        path = builder_site_template_pages_path(
          current_site, current_template, :published => p, :template => t
        )
      else
        path = builder_site_pages_path(
          current_site, current_page, :published => p, :template => t
        )
      end
      o += link_to(
        link.titleize,
        path,
        :class => "#{link.singularize}
          #{'active' if params[:published] == link.singularize}"
      )
    end
    o.html_safe
  end

  def page_template_filter(pages)
    templates = pages.collect(&:template).uniq.sort_by(&:title)
    content_tag(:div, :class => 'dropdown template-filter') do
      label = params[:template].blank? ? 'Any' : params[:template].titleize
      o = link_to(
        "Template: #{content_tag(:strong, label)}".html_safe,
        '#',
        :class => 'dropdown-trigger'
      )
      o += content_tag(:ul) do
        if current_page
          path = builder_site_page_path(
            current_site,
            current_page,
            :template => 'any',
            :published => params[:published]
          )
        else
          path = builder_site_pages_path(
            current_site,
            :template => 'any',
            :published => params[:published]
          )
        end
        o2 = content_tag(:li, link_to('Any', path))
        templates.each do |template|
          t = template.slug
          p = params[:published]
          if current_page
            path = builder_site_page_path(
              current_site, current_page, :template => t, :published => p
            )
          else
            path = builder_site_pages_path(
              current_site, :template => t, :published => p
            )
          end
          o2 += content_tag(:li, link_to(template.title, path))
        end
        o2.html_safe
      end
    end
  end

end
